import Foundation
import Observation

/// Manages real-time SMC sensor readings.
///
/// All reads go through the helper via XPC. On Apple Silicon the AppleSMC
/// IOConnectCallStructMethod path returns kIOReturnBadArgument from a user
/// process, so a root-side reader is required.
@Observable
final class SensorManager {
    private weak var fanController: FanController?
    private var timer: Timer?

    // MARK: - Published Values

    var fan0RPM: Float = 0
    var fan1RPM: Float = 0
    var keyboardTemp: Float = 0
    var cpuTemp: Float = 0
    var gpuTemp: Float = 0
    var batteryTemp: Float = 0
    var systemWatts: Float = 0
    var fanCount: Int = 2
    var isThrottling: Bool = false
    var lastUpdate: Date?

    // MARK: - Lifecycle

    init() {}

    deinit {
        stopPolling()
    }

    /// Inject the FanController used for XPC-mediated SMC reads.
    /// Must be called once at startup before polling produces values.
    func attach(fanController: FanController) {
        self.fanController = fanController
        if timer == nil {
            startPolling()
        }
    }

    // MARK: - Polling

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateReadings()
        }
        updateReadings()
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func updateReadings() {
        guard let fanController else { return }
        fanController.readSensors { [weak self] readings in
            guard let self else { return }
            if let v = readings[SMCKey.fanActual0] { self.fan0RPM = v }
            if let v = readings[SMCKey.fanActual1] { self.fan1RPM = v }
            self.keyboardTemp = self.acceptedTemperature(readings[SMCKey.keyboardTemp], current: self.keyboardTemp)
            self.cpuTemp = self.acceptedTemperature(readings[SMCKey.cpuComplex], current: self.cpuTemp)
            self.gpuTemp = self.acceptedTemperature(readings[SMCKey.gpuDie], current: self.gpuTemp)
            self.batteryTemp = self.acceptedTemperature(readings[SMCKey.batteryTemp], current: self.batteryTemp)
            if let watts = readings[SMCKey.systemWatts], watts.isFinite, watts >= 0 {
                self.systemWatts = watts
            }
            self.isThrottling = self.cpuTemp > 95
            if !readings.isEmpty { self.lastUpdate = Date() }
        }
    }

    private func acceptedTemperature(_ candidate: Float?, current: Float) -> Float {
        guard let candidate, candidate.isFinite, (10...125).contains(candidate) else {
            return current
        }
        return candidate
    }

    /// Build a SensorReading snapshot.
    func currentReading(lastComputedRPM: Float? = nil) -> SensorReading {
        SensorReading(
            timestamp: lastUpdate ?? Date(),
            fan0RPM: fan0RPM,
            fan1RPM: fan1RPM,
            keyboardTemp: keyboardTemp,
            cpuTemp: cpuTemp,
            gpuTemp: gpuTemp,
            batteryTemp: batteryTemp,
            lastComputedRPM: lastComputedRPM
        )
    }
}
