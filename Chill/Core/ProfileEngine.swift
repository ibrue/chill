import Foundation
import Observation

/// Manages fan profiles and target RPM computation
@Observable
final class ProfileEngine {
    var activeProfile: FanProfile = .auto
    var activePowerMode: PowerMode = .balanced
    private var smoothedRPM: Float?

    // Slew rate limits (RPM change per 2-second control tick)
    private let rampUpPerTick: Float = 400    // 200 RPM/sec — responsive to heat
    private let rampDownPerTick: Float = 200  // 100 RPM/sec — slow, smooth wind-down

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

    /// Compute target RPM using the adaptive curve for the current power mode
    func computeTargetRPM(for temp: Float, maxRPM: Float = 8000, profile: FanProfile, powerMode: PowerMode) -> Float {
        let curve = profile.curve(for: powerMode).sorted { $0.tempCelsius < $1.tempCelsius }

        guard !curve.isEmpty else { return maxRPM * 0.3 }

        if temp <= curve[0].tempCelsius {
            return maxRPM * curve[0].rpmPercent
        }
        if temp >= curve[curve.count - 1].tempCelsius {
            return maxRPM * curve[curve.count - 1].rpmPercent
        }

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

    /// Evaluate sensors and apply slew-rate limiting for smooth transitions
    func evaluate(sensors: SensorReading, fanMax: Float) -> Float {
        let profile = activeProfile
        let temp = sensors.value(for: profile.primarySensor)

        let rawTarget: Float
        if profile.isAdaptive {
            rawTarget = computeTargetRPM(for: temp, maxRPM: fanMax, profile: profile, powerMode: activePowerMode)
        } else {
            rawTarget = computeTargetRPM(for: temp, maxRPM: fanMax, profile: profile)
        }

        // First tick or after profile switch: seed directly
        guard let current = smoothedRPM else {
            smoothedRPM = rawTarget
            return rawTarget
        }

        // Slew rate limit: cap RPM change per tick
        let delta = rawTarget - current
        let clamped: Float
        if delta > 0 {
            clamped = current + min(delta, rampUpPerTick)
        } else {
            clamped = current + max(delta, -rampDownPerTick)
        }

        smoothedRPM = clamped
        return clamped
    }

    /// Switch active profile
    func switchProfile(_ profile: FanProfile) {
        activeProfile = profile
        smoothedRPM = nil  // re-seed on next tick
    }
}
