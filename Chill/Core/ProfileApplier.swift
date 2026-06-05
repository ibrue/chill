import Foundation
import Observation

/// Bridges sensor readings + active profile to fan writes via the helper.
///
/// Runs on a periodic loop while a non-Auto profile is active. When the user
/// selects Auto, releases control once and stays idle.
@Observable
final class ProfileApplier {
    private let sensorManager: SensorManager
    private let profileEngine: ProfileEngine
    private let fanController: FanController

    private var timer: Timer?
    private var lastTargetRPM: Float?
    private var lastObservedProfileID: UUID?

    /// Maximum RPM used for curve scaling. We learn this from F0Mx when
    /// available; until then use a conservative default that matches typical
    /// Apple Silicon MacBook Pro fans.
    private var fanMaxRPM: Float = 6500

    /// How often to re-evaluate the curve and push a target to the helper.
    private let tickInterval: TimeInterval = 2.0

    init(sensorManager: SensorManager, profileEngine: ProfileEngine, fanController: FanController) {
        self.sensorManager = sensorManager
        self.profileEngine = profileEngine
        self.fanController = fanController
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // Apply immediately so the first profile change doesn't wait 2s.
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let profile = profileEngine.activeProfile

        // Detect a profile switch; clear hysteresis state when it happens.
        if lastObservedProfileID != profile.id {
            lastObservedProfileID = profile.id
            lastTargetRPM = nil
            if profile.name == "Auto" {
                fanController.setAutoMode { _ in }
                fanController.activeProfileName = profile.name
                return
            }
        }

        if profile.name == "Auto" {
            // Already released; nothing to do until profile changes.
            return
        }

        let reading = sensorManager.currentReading(lastComputedRPM: lastTargetRPM)
        // Skip if we have no real sensor data yet; the helper readSensors
        // populates these on the first XPC round-trip.
        if reading.cpuTemp == 0 && reading.gpuTemp == 0 && reading.keyboardTemp == 0 {
            return
        }

        fanController.activeProfileName = profile.name

        // Fanless Macs (e.g. MacBook Air) report 0 fans: there is nothing to
        // drive, so Chill just monitors temperatures. Don't issue fan writes.
        guard sensorManager.fanCount > 0 else { return }

        let target = profileEngine.evaluate(sensors: reading, fanMax: fanMaxRPM)
        lastTargetRPM = target

        fanController.setFanMode(manual: true, fanIndex: 0, targetRPM: target) { _ in }
        if sensorManager.fanCount > 1 {
            fanController.setFanMode(manual: true, fanIndex: 1, targetRPM: target) { _ in }
        }
    }
}
