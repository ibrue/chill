import Foundation
import IOKit

// MARK: - SMC Parameter Structure
// Must match the kernel AppleSMC driver layout exactly.
// The canonical C struct is 80 bytes. Swift's natural alignment
// can add padding, so we verify with a static assert below.

struct SMCParamStruct {
    var key: UInt32 = 0                          // 4 bytes
    var vers: (UInt8, UInt8, UInt8, UInt8,        // vers: major, minor, build, reserved,
               UInt16) = (0, 0, 0, 0, 0)         //        release — 6 bytes total
    var pLimitData: (UInt16, UInt16,              // pLimitData: version, length,
                     UInt32, UInt32, UInt32)       //   cpuPLimit, gpuPLimit, memPLimit — 16 bytes
                   = (0, 0, 0, 0, 0)
    var keyInfo: SMCKeyInfoData = SMCKeyInfoData() // 10 bytes (padded to 12 by Swift)
    var padding: UInt16 = 0                       // align to match C layout
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

    func getBytesArray() -> [UInt8] {
        let mirror = Mirror(reflecting: bytes)
        return mirror.children.compactMap { $0.value as? UInt8 }
    }

    mutating func setBytesArray(_ data: [UInt8]) {
        for (i, byte) in data.prefix(32).enumerated() {
            switch i {
            case 0: bytes.0 = byte; case 1: bytes.1 = byte
            case 2: bytes.2 = byte; case 3: bytes.3 = byte
            case 4: bytes.4 = byte; case 5: bytes.5 = byte
            case 6: bytes.6 = byte; case 7: bytes.7 = byte
            case 8: bytes.8 = byte; case 9: bytes.9 = byte
            case 10: bytes.10 = byte; case 11: bytes.11 = byte
            case 12: bytes.12 = byte; case 13: bytes.13 = byte
            case 14: bytes.14 = byte; case 15: bytes.15 = byte
            case 16: bytes.16 = byte; case 17: bytes.17 = byte
            case 18: bytes.18 = byte; case 19: bytes.19 = byte
            case 20: bytes.20 = byte; case 21: bytes.21 = byte
            case 22: bytes.22 = byte; case 23: bytes.23 = byte
            case 24: bytes.24 = byte; case 25: bytes.25 = byte
            case 26: bytes.26 = byte; case 27: bytes.27 = byte
            case 28: bytes.28 = byte; case 29: bytes.29 = byte
            case 30: bytes.30 = byte; case 31: bytes.31 = byte
            default: break
            }
        }
    }
}

struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

// MARK: - Global Shared Instance

let globalSMCBridge = SMCBridge()

// MARK: - SMCBridge

class SMCBridge {
    private let queue = DispatchQueue(label: "com.chill.smc", qos: .userInitiated)
    private var connection: io_connect_t = 0
    private var isConnected = false

    private static let kSMCHandleYPCEvent: UInt32 = 2

    private enum SMCCommand: UInt8 {
        case readKey = 5
        case writeKey = 6
        case getKeyInfo = 9
    }

    init() {
        connect()
    }

    deinit {
        disconnect()
    }

    // MARK: - Connection

    private func connect() {
        queue.sync {
            let service = IOServiceGetMatchingService(
                kIOMainPortDefault,
                IOServiceMatching("AppleSMC")
            )
            guard service != IO_OBJECT_NULL else {
                print("[SMC] AppleSMC service not found")
                return
            }
            let kr = IOServiceOpen(service, mach_task_self_, 0, &connection)
            IOObjectRelease(service)
            guard kr == KERN_SUCCESS else {
                print("[SMC] IOServiceOpen failed: \(kr)")
                return
            }
            isConnected = true
            let structSize = MemoryLayout<SMCParamStruct>.size
            print("[SMC] Connected to AppleSMC (struct size: \(structSize) bytes)")
        }
    }

    private func disconnect() {
        queue.sync {
            if isConnected && connection != 0 {
                IOServiceClose(connection)
                isConnected = false
            }
        }
    }

    // MARK: - Low-level SMC Call

    private func callSMC(_ inputStruct: inout SMCParamStruct) -> kern_return_t {
        var outputSize = MemoryLayout<SMCParamStruct>.size
        return withUnsafeMutablePointer(to: &inputStruct) { ptr in
            IOConnectCallStructMethod(
                connection,
                Self.kSMCHandleYPCEvent,
                ptr,
                MemoryLayout<SMCParamStruct>.size,
                ptr,
                &outputSize
            )
        }
    }

    // MARK: - Read

    private func readSMC(key: String) -> SMCParamStruct? {
        return queue.sync {
            guard isConnected else {
                print("[SMC] readSMC(\(key)): not connected")
                return nil
            }

            // Step 1: Get key info
            var infoParam = SMCParamStruct()
            infoParam.key = fourCharCode(key)
            infoParam.data8 = SMCCommand.getKeyInfo.rawValue

            let infoKR = callSMC(&infoParam)
            guard infoKR == KERN_SUCCESS else {
                print("[SMC] getKeyInfo('\(key)') failed: 0x\(String(infoKR, radix: 16))")
                return nil
            }

            // Step 2: Read key value
            var readParam = SMCParamStruct()
            readParam.key = fourCharCode(key)
            readParam.keyInfo = infoParam.keyInfo
            readParam.data8 = SMCCommand.readKey.rawValue

            let readKR = callSMC(&readParam)
            guard readKR == KERN_SUCCESS else {
                print("[SMC] readKey('\(key)') failed: 0x\(String(readKR, radix: 16))")
                return nil
            }

            return readParam
        }
    }

    // MARK: - Write

    private func writeSMC(key: String, bytes: [UInt8]) -> Bool {
        return queue.sync {
            guard isConnected else { return false }

            var infoParam = SMCParamStruct()
            infoParam.key = fourCharCode(key)
            infoParam.data8 = SMCCommand.getKeyInfo.rawValue

            guard callSMC(&infoParam) == KERN_SUCCESS else { return false }

            var writeParam = SMCParamStruct()
            writeParam.key = fourCharCode(key)
            writeParam.keyInfo = infoParam.keyInfo
            writeParam.data8 = SMCCommand.writeKey.rawValue
            writeParam.setBytesArray(bytes)

            return callSMC(&writeParam) == KERN_SUCCESS
        }
    }

    // MARK: - Public API

    func readFloat(key: String) -> Float? {
        guard let param = readSMC(key: key) else { return nil }
        let bytes = param.getBytesArray()
        let type = SMCType.fromTypeCode(param.keyInfo.dataType)

        switch type {
        case .float32:
            return floatFromSMCBytes(bytes)
        case .sp78:
            guard bytes.count >= 2 else { return nil }
            let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
            return Float(raw) / 256.0
        default:
            return floatFromSMCBytes(bytes)
        }
    }

    func writeFloat(key: String, value: Float) -> Bool {
        let bytes = smcBytesFromFloat(value)
        return writeSMC(key: key, bytes: bytes)
    }

    func readUInt8(key: String) -> UInt8? {
        guard let param = readSMC(key: key) else { return nil }
        return uint8FromSMCBytes(param.getBytesArray())
    }

    func writeUInt8(key: String, value: UInt8) -> Bool {
        return writeSMC(key: key, bytes: smcBytesFromUInt8(value))
    }

    func readFanCount() -> Int? {
        guard let count = readUInt8(key: SMCKey.fanCount) else { return nil }
        return Int(count)
    }

    /// Scan a list of SMC keys and return the first that gives a non-zero reading
    func findWorkingKey(from candidates: [String]) -> (key: String, value: Float)? {
        for key in candidates {
            if let val = readFloat(key: key), val > 0 {
                return (key, val)
            }
        }
        return nil
    }

    /// Probe common temperature keys and print what's available
    func discoverSensors() {
        let keysToProbe = [
            // CPU
            "Tp09", "Tp0T", "Tp01", "Tp05",  // CPU efficiency/perf core temps (Apple Silicon)
            "TCXC",                             // CPU complex (Intel-era, sometimes Apple Silicon)
            "Tc0a", "Tc0b", "Tc0c", "Tc0d",   // CPU core temps
            "TC0D", "TC0P", "TC0F",             // CPU die/proximity
            // GPU
            "TG0D", "TG0P", "Tg05", "Tg0D",
            // Keyboard / palm rest
            "Ts0S", "Ts0P", "Ts1S", "Ts1P",
            "TH0A", "TH0B", "TH0C",           // Heatpipe
            // Battery
            "TB1T", "TB0T", "TB2T",
            // Ambient
            "TA0P", "TA1P",
            // SSD
            "TN0D", "TN1D",
            // Fan actual RPM
            "F0Ac", "F1Ac",
            // Fan count
            "FNum",
            // Power
            "PSTR",
        ]

        print("[SMC] === Sensor Discovery ===")
        for key in keysToProbe {
            if let param = readSMC(key: key) {
                let bytes = Array(param.getBytesArray().prefix(4))
                let typeCode = param.keyInfo.dataType
                let typeBytes = withUnsafeBytes(of: typeCode.bigEndian) { Array($0) }
                let typeStr = String(bytes: typeBytes, encoding: .ascii) ?? "????"
                let size = param.keyInfo.dataSize

                let type = SMCType.fromTypeCode(typeCode)
                var displayVal: String
                switch type {
                case .float32:
                    displayVal = "\(floatFromSMCBytes(bytes)) (flt)"
                case .sp78:
                    let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
                    displayVal = "\(Float(raw) / 256.0) (sp78)"
                case .uint8:
                    displayVal = "\(bytes[0]) (ui8)"
                case .uint16:
                    displayVal = "\(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) (ui16)"
                default:
                    displayVal = "bytes=\(bytes) type=\(typeStr)"
                }
                print("[SMC]   \(key) [\(typeStr) \(size)B] = \(displayVal)")
            }
        }
        print("[SMC] === End Discovery ===")
    }

    // MARK: - Helper

    private func fourCharCode(_ str: String) -> UInt32 {
        let chars = Array(str.utf8)
        var result: UInt32 = 0
        for i in 0..<min(4, chars.count) {
            result = (result << 8) | UInt32(chars[i])
        }
        for _ in chars.count..<4 {
            result = (result << 8) | UInt32(0x20) // space
        }
        return result
    }
}
