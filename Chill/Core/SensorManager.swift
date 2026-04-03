import Foundation
import Observation

/// Manages real-time SMC sensor readings
/// No root required for reads on Apple Silicon
@Observable
final class SensorManager {
    private let smc = globalSMCBridge
    private var timer: Timer?

    // MARK: - Published Values

    var fan0RPM: Float = 0
    var fan1RPM: Float = 0
    var keyboardTemp: Float = 0
    var cpuTemp: Float = 0
    var gpuTemp: Float = 0
    var batteryTemp: Float = 0
    var fanCount: Int = 2
    var isThrottling: Bool = false

    // MARK: - History (rolling 60 samples = ~2 min at 2s interval)

    private static let maxHistoryCount = 60
    private var nextHistoryID = 0

    var fan0History: [TimestampedValue] = []
    var fan1History: [TimestampedValue] = []
    var cpuTempHistory: [TimestampedValue] = []

    // For forwarding to helper
    var allReadings: [String: Float] {
        [
            SMCKey.fanActual0: fan0RPM,
            SMCKey.fanActual1: fan1RPM,
            SMCKey.keyboardTemp: keyboardTemp,
            SMCKey.cpuComplex: cpuTemp,
            SMCKey.gpuDie: gpuTemp,
            SMCKey.batteryTemp: batteryTemp,
        ]
    }

    // MARK: - Lifecycle

    init() {
        // Read fan count once at startup
        fanCount = smc.readFanCount() ?? 2

        // Start polling
        startPolling()
    }

    deinit {
        stopPolling()
    }

    // MARK: - Polling

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateReadings()
        }
        // Initial read
        updateReadings()
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func updateReadings() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            // Read all values on background thread
            let f0 = self.smc.readFloat(key: SMCKey.fanActual0)
            let f1 = self.smc.readFloat(key: SMCKey.fanActual1)
            let kbd = self.smc.readFloat(key: SMCKey.keyboardTemp)
            let cpu = self.smc.readFloat(key: SMCKey.cpuComplex)
            let gpu = self.smc.readFloat(key: SMCKey.gpuDie)
            let bat = self.smc.readFloat(key: SMCKey.batteryTemp)

            // Single batch update on main thread
            DispatchQueue.main.async {
                if let v = f0 { self.fan0RPM = v }
                if let v = f1 { self.fan1RPM = v }
                if let v = kbd { self.keyboardTemp = v }
                if let v = cpu { self.cpuTemp = v }
                if let v = gpu { self.gpuTemp = v }
                if let v = bat { self.batteryTemp = v }

                self.isThrottling = self.cpuTemp > 95

                // Append history
                let now = Date()
                let id = self.nextHistoryID
                self.nextHistoryID += 1

                self.fan0History.append(TimestampedValue(id: id, date: now, value: self.fan0RPM))
                self.fan1History.append(TimestampedValue(id: id, date: now, value: self.fan1RPM))
                self.cpuTempHistory.append(TimestampedValue(id: id, date: now, value: self.cpuTemp))

                let max = Self.maxHistoryCount
                if self.fan0History.count > max { self.fan0History.removeFirst() }
                if self.fan1History.count > max { self.fan1History.removeFirst() }
                if self.cpuTempHistory.count > max { self.cpuTempHistory.removeFirst() }
            }
        }
    }
}
