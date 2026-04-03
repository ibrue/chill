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

            let readings = [
                (SMCKey.fanActual0, \SensorManager.fan0RPM),
                (SMCKey.fanActual1, \SensorManager.fan1RPM),
                (SMCKey.keyboardTemp, \SensorManager.keyboardTemp),
                (SMCKey.cpuComplex, \SensorManager.cpuTemp),
                (SMCKey.gpuDie, \SensorManager.gpuTemp),
                (SMCKey.batteryTemp, \SensorManager.batteryTemp),
            ]

            for (key, keyPath) in readings {
                if let value = self.smc.readFloat(key: key) {
                    DispatchQueue.main.async {
                        self[keyPath: keyPath] = value
                    }
                }
            }

            // Estimate throttling (CPU temp > 95°C typically triggers throttling)
            let shouldThrottle = self.cpuTemp > 95
            DispatchQueue.main.async {
                self.isThrottling = shouldThrottle
            }
        }
    }
}
