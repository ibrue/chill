import Foundation

// MARK: - Type Conversions

/// Convert a byte array (from SMC) to an IEEE 754 float (little-endian)
/// Apple Silicon uses standard IEEE 754 format (not Intel fixed-point)
func floatFromSMCBytes(_ bytes: [UInt8]) -> Float {
    guard bytes.count >= 4 else { return 0 }
    var value: Float = 0
    let slice = Array(bytes.prefix(4))
    withUnsafeMutableBytes(of: &value) { dest in
        slice.withUnsafeBytes { src in
            dest.copyMemory(from: src)
        }
    }
    return value
}

/// Convert a Float to SMC byte array (little-endian IEEE 754)
func smcBytesFromFloat(_ value: Float) -> [UInt8] {
    withUnsafeBytes(of: value) { ptr in
        Array(ptr.prefix(4))
    }
}

/// Convert a single byte from SMC (UInt8)
func uint8FromSMCBytes(_ bytes: [UInt8]) -> UInt8 {
    guard !bytes.isEmpty else { return 0 }
    return bytes[0]
}

/// Convert UInt8 to SMC byte array
func smcBytesFromUInt8(_ value: UInt8) -> [UInt8] {
    [value]
}

/// Convert 2-byte big-endian to UInt16
func uint16FromSMCBytes(_ bytes: [UInt8]) -> UInt16 {
    guard bytes.count >= 2 else { return 0 }
    return UInt16(bytes[0]) << 8 | UInt16(bytes[1])
}

/// Convert UInt16 to 2-byte big-endian
func smcBytesFromUInt16(_ value: UInt16) -> [UInt8] {
    [UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
}

// MARK: - SMC Type System

/// SMC data type descriptors
enum SMCType {
    case uint8
    case uint16
    case uint32
    case float32  // IEEE 754
    case sp78     // Fixed-point with 7 bits integer, 8 bits fractional
    case unknown

    /// Determine type from SMC type code
    static func fromTypeCode(_ code: UInt32) -> SMCType {
        let bytes = withUnsafeBytes(of: code) { Array($0) }
        let chars = String(bytes: bytes, encoding: .ascii) ?? ""

        switch chars {
        case "ui8 ": return .uint8
        case "ui16": return .uint16
        case "ui32": return .uint32
        case "flt ": return .float32
        case "sp78": return .sp78
        default: return .unknown
        }
    }

    /// Get byte length for this type
    var byteLength: Int {
        switch self {
        case .uint8: return 1
        case .uint16: return 2
        case .uint32: return 4
        case .float32: return 4
        case .sp78: return 2
        case .unknown: return 0
        }
    }
}

// MARK: - SMC Value Container

/// Holds a value read from SMC with its type information
struct SMCValue {
    let bytes: [UInt8]
    let type: SMCType

    /// Get as Float (works for float32 and sp78)
    var floatValue: Float {
        switch type {
        case .float32:
            return floatFromSMCBytes(bytes)
        case .sp78:
            // sp78 is fixed-point: 7 int bits, 8 frac bits
            // value = (UInt16 as signed) / 256.0
            let uint16val = uint16FromSMCBytes(bytes)
            let signed = Int16(bitPattern: uint16val)
            return Float(signed) / 256.0
        default:
            return 0
        }
    }

    /// Get as UInt8
    var uint8Value: UInt8 {
        switch type {
        case .uint8:
            return uint8FromSMCBytes(bytes)
        default:
            return 0
        }
    }

    /// Get as UInt16
    var uint16Value: UInt16 {
        switch type {
        case .uint16:
            return uint16FromSMCBytes(bytes)
        default:
            return 0
        }
    }

    /// Get as UInt32
    var uint32Value: UInt32 {
        guard bytes.count >= 4 else { return 0 }
        return UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
    }
}

// MARK: - Errors

enum SMCError: LocalizedError {
    case ioKitError(String)
    case invalidDataFormat
    case connectionFailed
    case writeNotPermitted
    case keyNotFound
    case unknown

    var errorDescription: String? {
        switch self {
        case .ioKitError(let msg):
            return "IOKit error: \(msg)"
        case .invalidDataFormat:
            return "Invalid SMC data format"
        case .connectionFailed:
            return "Failed to connect to SMC"
        case .writeNotPermitted:
            return "SMC write not permitted (need root)"
        case .keyNotFound:
            return "SMC key not found on this Mac"
        case .unknown:
            return "Unknown SMC error"
        }
    }
}
