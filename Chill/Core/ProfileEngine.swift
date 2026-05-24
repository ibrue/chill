import Foundation
import Observation

/// Manages fan profiles and target RPM computation
@Observable
final class ProfileEngine {
    var selectedProfile: FanProfile = .auto
    var ruleOverrideProfile: FanProfile?
    private var lastRPMDecreaseTime: Date = Date()

    var activeProfile: FanProfile {
        ruleOverrideProfile ?? selectedProfile
    }

    // MARK: - Profile Evaluation

    /// Compute target RPM for a given temperature using linear interpolation
    /// - Parameters:
    ///   - temp: Current temperature in Celsius
    ///   - maxRPM: Maximum RPM supported by this fan
    ///   - profile: The profile to use for the curve
    /// - Returns: Target RPM value
    func computeTargetRPM(for temp: Float, maxRPM: Float = 8000, profile: FanProfile) -> Float {
        let curve = profile.curve.sorted { $0.tempCelsius < $1.tempCelsius }

        guard !curve.isEmpty else { return maxRPM * 0.3 }

        // Below minimum temp: minimum RPM
        if temp <= curve[0].tempCelsius {
            return maxRPM * curve[0].rpmPercent
        }

        // Above maximum temp: maximum RPM
        if temp >= curve[curve.count - 1].tempCelsius {
            return maxRPM * curve[curve.count - 1].rpmPercent
        }

        // Find surrounding points and interpolate
        for i in 0..<(curve.count - 1) {
            let current = curve[i]
            let next = curve[i + 1]

            if temp >= current.tempCelsius && temp < next.tempCelsius {
                let ratio = (temp - current.tempCelsius) / (next.tempCelsius - current.tempCelsius)
                let rpmPercent = current.rpmPercent + ratio * (next.rpmPercent - current.rpmPercent)
                return maxRPM * rpmPercent
            }
        }

        return maxRPM * 0.5
    }

    /// Evaluate sensors and apply hysteresis
    /// - Parameters:
    ///   - sensors: Current sensor readings
    ///   - fanMax: Maximum RPM for the fan
    /// - Returns: Recommended target RPM
    func evaluate(sensors: SensorReading, fanMax: Float) -> Float {
        let profile = activeProfile

        // Pick primary sensor value
        let temp = sensors.value(for: profile.primarySensor)

        var targetRPM = computeTargetRPM(for: temp, maxRPM: fanMax, profile: profile)

        // Apply hysteresis: only allow RPM increases immediately,
        // but delay decreases by checking elapsed time
        let now = Date()
        let timeSinceLastDecrease = now.timeIntervalSince(lastRPMDecreaseTime)

        if targetRPM < (sensors.lastComputedRPM ?? targetRPM) {
            // We want to decrease RPM
            if timeSinceLastDecrease > Double(profile.hysteresisDegrees) {
                // Enough time has passed; allow the decrease
                lastRPMDecreaseTime = now
            } else {
                // Maintain previous RPM
                targetRPM = sensors.lastComputedRPM ?? targetRPM
            }
        } else {
            // Increase: apply immediately
            lastRPMDecreaseTime = now
        }

        return targetRPM
    }

    /// Switch active profile
    func switchProfile(_ profile: FanProfile) {
        selectedProfile = profile
        lastRPMDecreaseTime = Date()
    }

    func applyRuleOverride(_ profile: FanProfile?) {
        ruleOverrideProfile = profile
        lastRPMDecreaseTime = Date()
    }
}
