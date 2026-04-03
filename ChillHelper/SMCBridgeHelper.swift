import Foundation
import IOKit

/// Helper wrapper around SMCBridge for privileged operations (runs as root)
/// Handles fan control state machine and Ftst maintenance
class SMCBridgeHelper {
    private let smc = SMCBridge()  // Helper runs as root — full read/write access
    private var isUnlocked = false

    // MARK: - Unlock Management

    /// Unlock SMC by writing Ftst=1
    /// This suppresses thermalmonitord and allows manual fan control
    func unlock() {
        let success = smc.writeUInt8(key: SMCKey.ftst, value: 1)
        if success {
            isUnlocked = true
            print("[SMCHelper] SMC unlocked (Ftst=1)")
        } else {
            print("[SMCHelper] Failed to unlock SMC")
        }
    }

    /// Release SMC control and let system take over
    func releaseControl() {
        let success = smc.writeUInt8(key: SMCKey.ftst, value: 0)
        if success {
            isUnlocked = false
            print("[SMCHelper] SMC control released")
        }
    }

    // MARK: - Fan Control

    /// Set a fan to manual mode with target RPM
    /// - Parameters:
    ///   - fanIndex: 0 or 1
    ///   - targetRPM: Target RPM value (float)
    /// - Returns: success
    func setManualMode(fanIndex: Int, targetRPM: Float) -> Bool {
        let modeKey = fanIndex == 0 ? SMCKey.fanMode0 : SMCKey.fanMode1
        let targetKey = fanIndex == 0 ? SMCKey.fanTarget0 : SMCKey.fanTarget1

        // Set mode to manual (1)
        guard smc.writeUInt8(key: modeKey, value: 1) else {
            print("[SMCHelper] Failed to set fan \(fanIndex) mode")
            return false
        }

        // Write target RPM (IEEE 754 float, little-endian)
        guard smc.writeFloat(key: targetKey, value: targetRPM) else {
            print("[SMCHelper] Failed to set fan \(fanIndex) target RPM")
            return false
        }

        print("[SMCHelper] Set fan \(fanIndex) to manual mode, target=\(targetRPM) RPM")
        return true
    }

    /// Set a fan back to auto mode
    /// - Parameters:
    ///   - fanIndex: 0 or 1
    /// - Returns: success
    func setAutoMode(fanIndex: Int = 0) -> Bool {
        let modeKey = fanIndex == 0 ? SMCKey.fanMode0 : SMCKey.fanMode1

        // Set mode to auto (0)
        guard smc.writeUInt8(key: modeKey, value: 0) else {
            print("[SMCHelper] Failed to set fan \(fanIndex) to auto")
            return false
        }

        print("[SMCHelper] Set fan \(fanIndex) to auto mode")
        return true
    }

    /// Return both fans to auto mode and release control
    func setAutoMode() -> Bool {
        let success0 = setAutoMode(fanIndex: 0)
        let success1 = setAutoMode(fanIndex: 1)
        releaseControl()
        return success0 && success1
    }

    // MARK: - Sensor Reads

    /// Read a float value from SMC
    func readFloat(key: String) -> Float? {
        smc.readFloat(key: key)
    }

    /// Read a UInt8 value from SMC
    func readUInt8(key: String) -> UInt8? {
        smc.readUInt8(key: key)
    }
}
