import Foundation

@objc protocol ChillXPCProtocol {
    /// Set manual fan control mode with target RPM
    /// - Parameters:
    ///   - manual: true for manual mode, false for auto
    ///   - fanIndex: 0 or 1 (which fan to control)
    ///   - targetRPM: Target RPM as a float (0.0-8000.0 typical range)
    ///   - reply: Completion handler returns success boolean
    func setFanMode(manual: Bool, fanIndex: Int, targetRPM: Float, reply: @escaping (Bool) -> Void)

    /// Return to automatic fan control
    /// - Parameter reply: Completion handler returns success boolean
    func setAutoMode(reply: @escaping (Bool) -> Void)

    /// Read current sensor values from SMC
    /// - Parameter reply: Completion handler returns dict of sensor key -> temperature/RPM value
    func readSensors(reply: @escaping ([String: Float]) -> Void)

    /// Get current fan control status
    /// - Parameter reply: Completion handler returns (isManual, fan0RPM, fan1RPM)
    func getStatus(reply: @escaping (Bool, Float, Float) -> Void)
}
