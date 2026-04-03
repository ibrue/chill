import Foundation

struct SensorReading {
    var timestamp: Date = Date()
    var fan0RPM: Float = 0
    var fan1RPM: Float = 0
    var keyboardTemp: Float = 0
    var cpuTemp: Float = 0
    var gpuTemp: Float = 0
    var batteryTemp: Float = 0
    var lastComputedRPM: Float?

    /// Get temperature value for a sensor key
    func value(for sensorKey: String) -> Float {
        switch sensorKey {
        case SMCKey.keyboardTemp:
            return keyboardTemp
        case SMCKey.cpuComplex, SMCKey.cpuProximity:
            return cpuTemp
        case SMCKey.gpuDie:
            return gpuTemp
        case SMCKey.batteryTemp:
            return batteryTemp
        default:
            return cpuTemp  // Fallback
        }
    }

    /// Create from sensor manager
    static func fromSensorManager(_ manager: SensorManager) -> SensorReading {
        SensorReading(
            timestamp: Date(),
            fan0RPM: manager.fan0RPM,
            fan1RPM: manager.fan1RPM,
            keyboardTemp: manager.keyboardTemp,
            cpuTemp: manager.cpuTemp,
            gpuTemp: manager.gpuTemp,
            batteryTemp: manager.batteryTemp
        )
    }
}
