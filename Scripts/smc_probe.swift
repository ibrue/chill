#!/usr/bin/env swift
//
// Read-only SMC probe for diagnosing Chill fan control on Apple Silicon.
//
// Run as root (the AppleSMC user client rejects writes, and some reads, from a
// normal process):
//
//     sudo swift Scripts/smc_probe.swift
//
// It prints, for every fan-related key, the SMC data type, byte size, raw bytes,
// and the value decoded both as a little-endian float and as an integer. Run it
// while a Chill profile (e.g. Performance) is active so we can see whether the
// helper's F0Md / F0Tg writes actually stuck and whether F0Ac tracks the target.
//
// This file is self-contained (it does not depend on the app's SMCBridge) so it
// can be run directly with the `swift` interpreter.

import Foundation
import IOKit

// MARK: - SMC param struct (must match the kernel AppleSMC layout: 80 bytes)

struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

struct SMCParamStruct {
    var key: UInt32 = 0
    var vers: (UInt8, UInt8, UInt8, UInt8, UInt16) = (0, 0, 0, 0, 0)
    var pLimitData: (UInt16, UInt16, UInt32, UInt32, UInt32) = (0, 0, 0, 0, 0)
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    ) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

    func bytesArray() -> [UInt8] {
        let m = Mirror(reflecting: bytes)
        return m.children.compactMap { $0.value as? UInt8 }
    }
}

let kSMCHandleYPCEvent: UInt32 = 2
let cmdReadKey: UInt8 = 5
let cmdWriteKey: UInt8 = 6
let cmdGetKeyInfo: UInt8 = 9

// Set by the SIGINT handler so the write test can bail out and still restore.
var interrupted: sig_atomic_t = 0

func fourCharCode(_ s: String) -> UInt32 {
    var r: UInt32 = 0
    for b in s.utf8.prefix(4) { r = (r << 8) | UInt32(b) }
    return r
}

func typeString(_ code: UInt32) -> String {
    let b = withUnsafeBytes(of: code.bigEndian) { Array($0) }
    return String(bytes: b, encoding: .ascii) ?? "????"
}

var conn: io_connect_t = 0
let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
guard service != IO_OBJECT_NULL else { print("AppleSMC service not found"); exit(1) }
guard IOServiceOpen(service, mach_task_self_, 0, &conn) == KERN_SUCCESS else {
    print("IOServiceOpen failed (run with sudo)"); exit(1)
}
IOObjectRelease(service)

func call(_ p: inout SMCParamStruct) -> kern_return_t {
    var outSize = MemoryLayout<SMCParamStruct>.size
    return withUnsafeMutablePointer(to: &p) { ptr in
        IOConnectCallStructMethod(conn, kSMCHandleYPCEvent, ptr,
                                  MemoryLayout<SMCParamStruct>.size, ptr, &outSize)
    }
}

struct Reading { let type: String; let size: Int; let bytes: [UInt8] }

func read(_ key: String) -> Reading? {
    var info = SMCParamStruct()
    info.key = fourCharCode(key)
    info.data8 = cmdGetKeyInfo
    guard call(&info) == KERN_SUCCESS else { return nil }

    var rd = SMCParamStruct()
    rd.key = fourCharCode(key)
    rd.keyInfo = info.keyInfo
    rd.data8 = cmdReadKey
    guard call(&rd) == KERN_SUCCESS else { return nil }

    let size = Int(info.keyInfo.dataSize)
    return Reading(type: typeString(info.keyInfo.dataType),
                   size: size,
                   bytes: Array(rd.bytesArray().prefix(max(size, 1))))
}

func asFloatLE(_ b: [UInt8]) -> Float {
    guard b.count >= 4 else { return Float.nan }
    let u = UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24
    return Float(bitPattern: u)
}

func asInt(_ b: [UInt8]) -> UInt64 {
    var v: UInt64 = 0
    for (i, byte) in b.prefix(8).enumerated() { v |= UInt64(byte) << (8 * i) }
    return v
}

func keyInfo(_ key: String) -> SMCKeyInfoData? {
    var info = SMCParamStruct()
    info.key = fourCharCode(key)
    info.data8 = cmdGetKeyInfo
    guard call(&info) == KERN_SUCCESS else { return nil }
    return info.keyInfo
}

/// Write `bytes` to `key`, using the key's own dataSize/type from getKeyInfo.
/// Returns the raw kern_return_t so callers can see the real SMC status code.
@discardableResult
func writeRaw(_ key: String, _ bytes: [UInt8]) -> kern_return_t {
    guard let info = keyInfo(key) else { return KERN_FAILURE }
    var w = SMCParamStruct()
    w.key = fourCharCode(key)
    w.keyInfo = info
    w.data8 = cmdWriteKey
    for (i, b) in bytes.prefix(32).enumerated() {
        withUnsafeMutableBytes(of: &w.bytes) { $0[i] = b }
    }
    return call(&w)
}

func hexKR(_ k: kern_return_t) -> String { "0x" + String(UInt32(bitPattern: k), radix: 16) }

/// Best-effort CPU die temperature, trying the keys that vary across M-series.
func cpuTemp() -> Float {
    for k in ["Tp09", "Tp01", "Tp05", "Tp0T", "TCXC", "Tc0a"] {
        if let r = read(k) {
            let v = asFloatLE(r.bytes)
            if v.isFinite, v > 10, v < 125 { return v }
        }
    }
    return .nan
}

func floatLEBytes(_ v: Float) -> [UInt8] {
    let u = v.bitPattern
    return [UInt8(u & 0xff), UInt8((u >> 8) & 0xff), UInt8((u >> 16) & 0xff), UInt8((u >> 24) & 0xff)]
}

/// Encode an RPM target for a fan target key based on its actual SMC type.
func encodeTarget(_ key: String, _ rpm: Float) -> (bytes: [UInt8], type: String) {
    let t = keyInfo(key).map { typeString($0.dataType) } ?? "flt "
    switch t.trimmingCharacters(in: .whitespaces) {
    case "ui16":
        let v = UInt16(max(0, min(65535, rpm)))
        return ([UInt8(v & 0xff), UInt8(v >> 8)], t)
    case "fpe2": // 16-bit, 2 fractional bits, big-endian
        let v = UInt16(max(0, min(16383, rpm)) * 4)
        return ([UInt8(v >> 8), UInt8(v & 0xff)], t)
    default: // "flt " and unknown: little-endian float
        return (floatLEBytes(rpm), t)
    }
}

func pad(_ s: String, _ n: Int) -> String {
    s.count >= n ? s : s + String(repeating: " ", count: n - s.count)
}

// MARK: - Emergency restore
//
// `--restore` returns the fans to fully automatic control and exits. Use this if
// fans seem stuck off/on after a test: it clears manual mode on both fans and
// clears the Ftst suppression flag so macOS's thermal control takes over again.
if CommandLine.arguments.contains("--restore") {
    let f1 = read("F1Md") != nil
    let r0 = writeRaw("F0Md", [0])
    let r1: kern_return_t = f1 ? writeRaw("F1Md", [0]) : KERN_SUCCESS
    let rf = writeRaw("Ftst", [0])
    print("Restored automatic fan control.")
    print("  F0Md=0 -> \(hexKR(r0))\(f1 ? "   F1Md=0 -> \(hexKR(r1))" : "")   Ftst=0 -> \(hexKR(rf))")
    print("  F0Md now reads: \(read("F0Md").map { String(asInt($0.bytes)) } ?? "-"), Ftst now reads: \(read("Ftst").map { String(asInt($0.bytes)) } ?? "-")")
    IOServiceClose(conn)
    exit(0)
}

// MARK: - Fan mode sweep
//
// `--modetest` determines whether F0Md (fan mode) accepts ANY value the firmware
// honors. We hold Ftst=1, write each candidate value, and read it back. If every
// readback stays 3 regardless of what we write, software fan-mode override is
// firmware-locked on this Mac and no SMC approach will force the fans. If some
// value sticks, that's the real "manual" value for this machine.
if CommandLine.arguments.contains("--modetest") {
    print("Fan-mode sweep (holding Ftst=1). Writing F0Md candidate values and reading back:")
    print(pad("write", 8) + pad("rc", 10) + pad("read@0ms", 12) + "read@250ms")
    _ = writeRaw("Ftst", [1])
    usleep(200_000)
    for v in [UInt8(0), 1, 2, 3, 4, 5, 6, 7] {
        let rc = writeRaw("F0Md", [v])
        let r0 = read("F0Md").map { asInt($0.bytes) }.map(String.init) ?? "-"
        usleep(250_000)
        let r1 = read("F0Md").map { asInt($0.bytes) }.map(String.init) ?? "-"
        print(pad(String(v), 8) + pad(hexKR(rc), 10) + pad(r0, 12) + r1)
    }
    // Also: does writing F0Tg alone (mode untouched) get honored? Hold high target
    // for 4s and watch F0Ac.
    print("")
    let (tg, ty) = encodeTarget("F0Tg", 6000)
    print("Target-only test: F0Tg=6000 (type '\(ty)'), Ftst=1 held, 4s:")
    for t in 0...8 {
        _ = writeRaw("Ftst", [1])
        _ = writeRaw("F0Tg", tg)
        let tgRead = read("F0Tg").map { asFloatLE($0.bytes) } ?? .nan
        let ac = read("F0Ac").map { asFloatLE($0.bytes) } ?? .nan
        print("  t=\(Double(t) * 0.5)s  F0Tg readback=\(tgRead.isNaN ? "-" : String(format: "%.0f", tgRead))  F0Ac=\(ac.isNaN ? "-" : String(format: "%.0f", ac))")
        usleep(500_000)
    }
    _ = writeRaw("F0Md", [0]); _ = writeRaw("Ftst", [0])
    print("Restored (F0Md=0, Ftst=0).")
    IOServiceClose(conn)
    exit(0)
}

let keys = ["Ftst", "FNum",
            "F0Md", "F0Tg", "F0Ac", "F0Mn", "F0Mx",
            "F1Md", "F1Tg", "F1Ac", "F1Mn", "F1Mx"]

print(pad("KEY", 6) + pad("TYPE", 6) + pad("SIZE", 6) + pad("BYTES", 28) + pad("FLOAT_LE", 12) + "INT_LE")
print(String(repeating: "-", count: 78))
for k in keys {
    guard let r = read(k) else { print(pad(k, 6) + "(not available)"); continue }
    let hex = r.bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
    let f = asFloatLE(r.bytes)
    let floatStr = f.isNaN ? "-" : String(format: "%.1f", f)
    print(pad(k, 6) + pad(r.type, 6) + pad(String(r.size), 6) + pad(hex, 28) + pad(floatStr, 12) + String(asInt(r.bytes)))
}

// MARK: - Controlled write test (warms the die so the firmware floor lifts)
//
// On M3/M4 the firmware physically pins fans at 0 RPM while the die is cool, even
// with a correct manual unlock + target. So this test spins up CPU load to heat
// the die, then forces F0Md=1 / F0Tg=<target>, holding Ftst=1, and samples CPU
// temperature, the Ftst/F0Md readback, and F0Ac/F1Ac once a second. Reading the
// F0Md column tells us if manual mode engages (3 -> 1); reading F0Ac vs CPU temp
// tells us if the fan responds once it's warm enough.
//
// Args: optional target RPM (default 4500) and optional duration seconds
// (default 50). `--dump-only` skips the test.

let args = CommandLine.arguments
if args.contains("--dump-only") {
    IOServiceClose(conn)
    exit(0)
}
let numbers = args.compactMap { Float($0) }
let target = numbers.first ?? 4500
let duration = Int(numbers.dropFirst().first ?? 120)
let fan1Present = read("F1Ac") != nil

// If the user interrupts (Ctrl-C), break out of the loop so the restore code at
// the end still runs and the fans are handed back to macOS. Without this, an
// interrupted test would leave Ftst=1 / manual mode set and the fans stuck.
signal(SIGINT) { _ in interrupted = 1 }

// Heavy all-core load to help warm the die. On efficient M-chips this alone may
// not be enough - run a real benchmark (Cinebench, a big build) alongside to get
// the fans actually spinning.
var loadRunning = true
let cores = ProcessInfo.processInfo.activeProcessorCount
for _ in 0..<(cores * 2) {
    let t = Thread {
        var x = 1.0001
        while loadRunning {
            x = (x * 1.000003 + 0.5).squareRoot()
            x = (x + 1.0001).truncatingRemainder(dividingBy: 997.0) + 1.0
        }
    }
    t.start()
}

let (tgtBytes, tgtType) = encodeTarget("F0Tg", target)
print("")
print("Adaptive takeover test (\(cores * 2) load threads, target \(Int(target)) RPM, ~\(duration)s).")
print("Strategy: while the fans are off we do NOT suppress macOS, so it can spin")
print("them up. Once F0Ac>0, we engage Ftst=1 + F0Md=1 + F0Tg and watch for takeover.")
print("F0Tg type='\(tgtType)' bytes=\(tgtBytes.map { String(format: "%02x", $0) }.joined(separator: " "))")
print(pad("t(s)", 6) + pad("CPU\u{00B0}", 7) + pad("phase", 10) + pad("Ftst", 6) + pad("F0Md", 6) + pad("F0Ac", 8) + (fan1Present ? "F1Ac" : ""))

var tookOver = false
var fansEverSpun = false
var modeEngaged = false
var maxTemp: Float = 0
var maxAc: Float = 0

for tick in 0...duration {
    if interrupted != 0 { print("Interrupted; restoring..."); break }
    let acPre = read("F0Ac").map { asFloatLE($0.bytes) } ?? 0
    if acPre > 0 { fansEverSpun = true }

    let phase: String
    if acPre <= 0 && !tookOver {
        // Fans still off: let macOS spin them up. Do NOT suppress it.
        _ = writeRaw("Ftst", [0])
        phase = "warming"
    } else {
        // Fans are moving (or we already engaged): attempt/hold takeover.
        tookOver = true
        _ = writeRaw("Ftst", [1])
        _ = writeRaw("F0Md", [1])
        _ = writeRaw("F0Tg", tgtBytes)
        if fan1Present {
            _ = writeRaw("F1Md", [1])
            _ = writeRaw("F1Tg", encodeTarget("F1Tg", target).bytes)
        }
        phase = "takeover"
    }

    let temp = cpuTemp()
    let ftst = read("Ftst").map { asInt($0.bytes) } ?? 0
    let md = read("F0Md").map { asInt($0.bytes) } ?? 0
    let ac0 = read("F0Ac").map { asFloatLE($0.bytes) } ?? .nan
    let ac1 = read("F1Ac").map { asFloatLE($0.bytes) } ?? .nan
    if temp.isFinite { maxTemp = max(maxTemp, temp) }
    if ac0.isFinite { maxAc = max(maxAc, ac0) }
    if md == 1 { modeEngaged = true }

    print(pad(String(tick), 6)
          + pad(temp.isNaN ? "-" : String(format: "%.0f", temp), 7)
          + pad(phase, 10)
          + pad(String(ftst), 6)
          + pad(String(md), 6)
          + pad(ac0.isNaN ? "-" : String(format: "%.0f", ac0), 8)
          + (fan1Present ? (ac1.isNaN ? "-" : String(format: "%.0f", ac1)) : ""))
    Thread.sleep(forTimeInterval: 1.0)
}

// Stop the load, then restore automatic control.
loadRunning = false
_ = writeRaw("F0Md", [0])
if fan1Present { _ = writeRaw("F1Md", [0]) }
_ = writeRaw("Ftst", [0])
print("Restored auto mode (F0Md=0, Ftst=0); load stopped.")
print("")
print("SUMMARY")
print("  peak CPU temp: \(String(format: "%.0f", maxTemp))C    peak F0Ac: \(String(format: "%.0f", maxAc)) RPM")
print("  fans ever spun (macOS, F0Ac>0): \(fansEverSpun ? "YES" : "NO - never got hot enough; run a heavier load")")
print("  manual mode engaged (F0Md==1): \(modeEngaged ? "YES - software CAN control fans once warm" : "NO - F0Md stayed in System Mode 3")")

IOServiceClose(conn)
