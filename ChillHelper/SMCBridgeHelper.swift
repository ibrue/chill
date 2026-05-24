import Foundation
import IOKit

/// Helper wrapper around SMCBridge for privileged operations (runs as root).
/// Handles fan control state machine and Ftst maintenance.
///
/// Logging policy: every state transition is logged, but the 150ms maintain
/// loop is silent (it only logs when a write fails). This keeps the helper log
/// at a sane size — the previous version produced ~13M lines of repeated
/// "SMC unlocked" output.
class SMCBridgeHelper {
    private let smc = SMCBridge()
    private var unlockedLogged = false
    private var unlockFailureLogged = false

    // MARK: - Unlock Management

    /// Initial unlock, logged on transition. SMC writes are flaky cold —
    /// retry a handful of times with a small backoff before giving up.
    @discardableResult
    func unlock() -> Bool {
        var success = false
        for attempt in 0..<8 {
            if smc.writeUInt8(key: SMCKey.ftst, value: 1) {
                success = true
                break
            }
            if attempt < 7 {
                usleep(20_000) // 20 ms
            }
        }
        if success {
            if !unlockedLogged {
                print("[SMCHelper] SMC unlocked (Ftst=1)")
                unlockedLogged = true
            }
            unlockFailureLogged = false
        } else {
            if !unlockFailureLogged {
                print("[SMCHelper] Failed to unlock SMC after retries")
                unlockFailureLogged = true
            }
            unlockedLogged = false
        }
        return success
    }

    /// Repeated unlock from the maintain loop. Silent on success, logs once
    /// per failure transition. This is what the 150ms timer calls.
    func maintainUnlock() {
        let success = smc.writeUInt8(key: SMCKey.ftst, value: 1)
        if success {
            if unlockFailureLogged {
                print("[SMCHelper] SMC unlock recovered")
            }
            unlockedLogged = true
            unlockFailureLogged = false
        } else {
            if !unlockFailureLogged {
                print("[SMCHelper] Failed to maintain SMC unlock")
                unlockFailureLogged = true
            }
        }
    }

    /// Release SMC control and let system take over.
    @discardableResult
    func releaseControl() -> Bool {
        let success = smc.writeUInt8(key: SMCKey.ftst, value: 0)
        if success {
            print("[SMCHelper] SMC control released (Ftst=0)")
            unlockedLogged = false
        }
        return success
    }

    // MARK: - Fan Control

    /// Set a fan to manual mode with target RPM. Logs on each call (called
    /// only on real state transitions, not from the maintain loop).
    func setManualMode(fanIndex: Int, targetRPM: Float) -> Bool {
        let modeKey = fanIndex == 0 ? SMCKey.fanMode0 : SMCKey.fanMode1
        let targetKey = fanIndex == 0 ? SMCKey.fanTarget0 : SMCKey.fanTarget1

        guard smc.writeUInt8(key: modeKey, value: 1) else {
            print("[SMCHelper] Failed to set fan \(fanIndex) mode")
            return false
        }
        guard smc.writeFloat(key: targetKey, value: targetRPM) else {
            print("[SMCHelper] Failed to set fan \(fanIndex) target RPM")
            return false
        }
        print("[SMCHelper] Set fan \(fanIndex) to manual mode, target=\(targetRPM) RPM")
        return true
    }

    /// Re-apply manual fan target from the maintain loop. Silent on success.
    func reapplyManual(fanIndex: Int, targetRPM: Float) -> Bool {
        let modeKey = fanIndex == 0 ? SMCKey.fanMode0 : SMCKey.fanMode1
        let targetKey = fanIndex == 0 ? SMCKey.fanTarget0 : SMCKey.fanTarget1
        guard smc.writeUInt8(key: modeKey, value: 1) else { return false }
        return smc.writeFloat(key: targetKey, value: targetRPM)
    }

    /// Return a single fan to auto mode.
    @discardableResult
    func setAutoMode(fanIndex: Int) -> Bool {
        let modeKey = fanIndex == 0 ? SMCKey.fanMode0 : SMCKey.fanMode1
        guard smc.writeUInt8(key: modeKey, value: 0) else {
            print("[SMCHelper] Failed to set fan \(fanIndex) to auto")
            return false
        }
        print("[SMCHelper] Set fan \(fanIndex) to auto mode")
        return true
    }

    /// Return both fans to auto and release the unlock flag.
    /// Must unlock first because F*Md writes require Ftst=1.
    @discardableResult
    func setAutoMode() -> Bool {
        unlock()
        let s0 = setAutoMode(fanIndex: 0)
        let s1 = setAutoMode(fanIndex: 1)
        releaseControl()
        return s0 && s1
    }

    // MARK: - Sensor Reads

    func readFloat(key: String) -> Float? { smc.readFloat(key: key) }
    func readUInt8(key: String) -> UInt8? { smc.readUInt8(key: key) }
}
