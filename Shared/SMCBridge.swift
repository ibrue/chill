import Foundation
import IOKit

// MARK: - SMC Parameter Structure

/// SMC parameter struct for IOConnectCallStructMethod
/// Must match kernel SMC driver layout exactly
struct SMCParamStruct {
    var key: UInt32 = 0
    var vers: SMCVersion = SMCVersion()
    var pLimitData: SMCPLimitData = SMCPLimitData()
    var keyInfo: SMCKeyInfo = SMCKeyInfo()
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

    /// Extract 32 bytes from the tuple
    func getBytesArray() -> [UInt8] {
        let mirror = Mirror(reflecting: bytes)
        return mirror.children.compactMap { $0.value as? UInt8 }
    }

    /// Set bytes from array
    mutating func setBytesArray(_ data: [UInt8]) {
        for (i, byte) in data.prefix(32).enumerated() {
            switch i {
            case 0: bytes.0 = byte
            case 1: bytes.1 = byte
            case 2: bytes.2 = byte
            case 3: bytes.3 = byte
            case 4: bytes.4 = byte
            case 5: bytes.5 = byte
            case 6: bytes.6 = byte
            case 7: bytes.7 = byte
            case 8: bytes.8 = byte
            case 9: bytes.9 = byte
            case 10: bytes.10 = byte
            case 11: bytes.11 = byte
            case 12: bytes.12 = byte
            case 13: bytes.13 = byte
            case 14: bytes.14 = byte
            case 15: bytes.15 = byte
            case 16: bytes.16 = byte
            case 17: bytes.17 = byte
            case 18: bytes.18 = byte
            case 19: bytes.19 = byte
            case 20: bytes.20 = byte
            case 21: bytes.21 = byte
            case 22: bytes.22 = byte
            case 23: bytes.23 = byte
            case 24: bytes.24 = byte
            case 25: bytes.25 = byte
            case 26: bytes.26 = byte
            case 27: bytes.27 = byte
            case 28: bytes.28 = byte
            case 29: bytes.29 = byte
            case 30: bytes.30 = byte
            case 31: bytes.31 = byte
            default: break
            }
        }
    }
}

struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
}

struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

struct SMCKeyInfo {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

// MARK: - Global Shared Instance

/// Shared SMCBridge instance for the app target (read-only from user process)
let globalSMCBridge = SMCBridge()

// MARK: - SMCBridge

/// Thread-safe bridge to Apple SMC via IOKit
/// Handles all IOKit plumbing for SMC reads and writes
class SMCBridge {
    private let queue = DispatchQueue(label: "com.chill.smc", qos: .userInitiated)
    private var connection: io_connect_t = 0
    private var isConnected = false

    // MARK: - Lifecycle

    init() {
        connect()
    }

    deinit {
        disconnect()
    }

    // MARK: - Connection Management

    /// Establish connection to AppleSMC IOKit service
    private func connect() {
        queue.sync {
            let matchingDict = IOServiceMatching("AppleSMC")
            let service = IOServiceGetMatchingService(kIOMainPortDefault, matchingDict)
            guard service != IO_OBJECT_NULL else {
                print("[SMC] Failed to find AppleSMC service")
                return
            }

            let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
            IOObjectRelease(service)

            guard result == KERN_SUCCESS else {
                print("[SMC] IOServiceOpen failed: \(result)")
                return
            }

            isConnected = true
            print("[SMC] Connected to AppleSMC")
        }
    }

    /// Close IOKit connection
    private func disconnect() {
        queue.sync {
            if isConnected && connection != 0 {
                IOServiceClose(connection)
                isConnected = false
            }
        }
    }

    // MARK: - SMC Command Selectors
    // AppleSMC uses a single IOKit selector (kSMCHandleYPCEvent = 2)
    // The actual operation is specified in the data8 field of SMCParamStruct
    private static let kSMCHandleYPCEvent: UInt32 = 2

    private enum SMCCommand: UInt8 {
        case readKey = 5
        case writeKey = 6
        case getKeyInfo = 9
    }

    // MARK: - Low-level IOKit Operations

    /// Perform a read operation via IOConnectCallStructMethod
    private func readSMC(key: String) -> SMCParamStruct? {
        return queue.sync {
            guard isConnected else { return nil }

            // Step 1: Get key info
            var param = SMCParamStruct()
            param.key = fourCharCode(key)
            param.data8 = SMCCommand.getKeyInfo.rawValue

            var outputSize = MemoryLayout<SMCParamStruct>.size

            let result = withUnsafeMutablePointer(to: &param) { ptr in
                IOConnectCallStructMethod(
                    connection,
                    Self.kSMCHandleYPCEvent,
                    ptr,
                    MemoryLayout<SMCParamStruct>.size,
                    ptr,
                    &outputSize
                )
            }

            guard result == KERN_SUCCESS else {
                return nil
            }

            // Step 2: Read the key value
            var readParam = SMCParamStruct()
            readParam.key = fourCharCode(key)
            readParam.keyInfo = param.keyInfo
            readParam.data8 = SMCCommand.readKey.rawValue

            outputSize = MemoryLayout<SMCParamStruct>.size

            let readResult = withUnsafeMutablePointer(to: &readParam) { ptr in
                IOConnectCallStructMethod(
                    connection,
                    Self.kSMCHandleYPCEvent,
                    ptr,
                    MemoryLayout<SMCParamStruct>.size,
                    ptr,
                    &outputSize
                )
            }

            guard readResult == KERN_SUCCESS else {
                return nil
            }

            return readParam
        }
    }

    /// Perform a write operation via IOConnectCallStructMethod
    private func writeSMC(key: String, bytes: [UInt8]) -> Bool {
        return queue.sync {
            guard isConnected else { return false }

            // Step 1: Get key info
            var param = SMCParamStruct()
            param.key = fourCharCode(key)
            param.data8 = SMCCommand.getKeyInfo.rawValue

            var outputSize = MemoryLayout<SMCParamStruct>.size

            let infoResult = withUnsafeMutablePointer(to: &param) { ptr in
                IOConnectCallStructMethod(
                    connection,
                    Self.kSMCHandleYPCEvent,
                    ptr,
                    MemoryLayout<SMCParamStruct>.size,
                    ptr,
                    &outputSize
                )
            }

            guard infoResult == KERN_SUCCESS else {
                return false
            }

            // Step 2: Write the key value
            var writeParam = SMCParamStruct()
            writeParam.key = fourCharCode(key)
            writeParam.keyInfo = param.keyInfo
            writeParam.data8 = SMCCommand.writeKey.rawValue
            writeParam.setBytesArray(bytes)

            outputSize = MemoryLayout<SMCParamStruct>.size

            let writeResult = withUnsafeMutablePointer(to: &writeParam) { ptr in
                IOConnectCallStructMethod(
                    connection,
                    Self.kSMCHandleYPCEvent,
                    ptr,
                    MemoryLayout<SMCParamStruct>.size,
                    ptr,
                    &outputSize
                )
            }

            return writeResult == KERN_SUCCESS
        }
    }

    // MARK: - Public API

    /// Read a float value from SMC (handles flt and sp78 types automatically)
    func readFloat(key: String) -> Float? {
        guard let param = readSMC(key: key) else { return nil }
        let bytes = param.getBytesArray()
        let type = SMCType.fromTypeCode(param.keyInfo.dataType)

        switch type {
        case .float32:
            return floatFromSMCBytes(bytes)
        case .sp78:
            // sp78 fixed-point: value = Int16(big-endian) / 256.0
            guard bytes.count >= 2 else { return nil }
            let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
            return Float(raw) / 256.0
        default:
            // Try as IEEE 754 float as fallback
            return floatFromSMCBytes(bytes)
        }
    }

    /// Write a float value to SMC (requires root)
    func writeFloat(key: String, value: Float) -> Bool {
        let bytes = smcBytesFromFloat(value)
        return writeSMC(key: key, bytes: bytes)
    }

    /// Read a UInt8 value from SMC
    func readUInt8(key: String) -> UInt8? {
        guard let param = readSMC(key: key) else { return nil }
        return uint8FromSMCBytes(param.getBytesArray())
    }

    /// Write a UInt8 value to SMC (requires root)
    func writeUInt8(key: String, value: UInt8) -> Bool {
        let bytes = smcBytesFromUInt8(value)
        return writeSMC(key: key, bytes: bytes)
    }

    /// Read fan count
    func readFanCount() -> Int? {
        guard let count = readUInt8(key: SMCKey.fanCount) else { return nil }
        return Int(count)
    }

    // MARK: - Helper

    /// Convert a 4-character string to UInt32 (big-endian)
    private func fourCharCode(_ str: String) -> UInt32 {
        let chars = Array(str.utf8)
        var result: UInt32 = 0

        for i in 0..<min(4, chars.count) {
            result = (result << 8) | UInt32(chars[i])
        }

        // Pad with spaces if needed
        for _ in chars.count..<4 {
            result = (result << 8) | UInt32(Character(" ").asciiValue!)
        }

        return result
    }
}
