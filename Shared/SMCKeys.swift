import Foundation

/// SMC key constants for Apple Silicon Macs
enum SMCKey {
    // MARK: - Fan Control

    /// Unlock flag for fan control (Ftst=1 suppresses thermalmonitord)
    static let ftst = "Ftst"

    // Fan 0 (primary/larger)
    /// Fan 0 mode: 0=auto, 1=manual
    static let fanMode0 = "F0Md"
    /// Fan 0 target RPM (float32, LE)
    static let fanTarget0 = "F0Tg"
    /// Fan 0 actual RPM
    static let fanActual0 = "F0Ac"
    /// Fan 0 minimum RPM
    static let fanMin0 = "F0Mn"
    /// Fan 0 maximum RPM
    static let fanMax0 = "F0Mx"

    // Fan 1 (secondary/smaller)
    /// Fan 1 mode: 0=auto, 1=manual
    static let fanMode1 = "F1Md"
    /// Fan 1 target RPM (float32, LE)
    static let fanTarget1 = "F1Tg"
    /// Fan 1 actual RPM
    static let fanActual1 = "F1Ac"
    /// Fan 1 minimum RPM
    static let fanMin1 = "F1Mn"
    /// Fan 1 maximum RPM
    static let fanMax1 = "F1Mx"

    /// Number of fans
    static let fanCount = "FNum"

    // MARK: - Temperature Sensors
    // Keys vary by Mac model. These are the primary keys with fallbacks.

    /// Keyboard/palm rest temperature (primary sensor for Cool Keys profile)
    static let keyboardTemp = "Ts0P"        // palm rest proximity
    static let keyboardTempAlt = "Ts0S"     // palm rest (older models)
    /// CPU temperature — Apple Silicon perf core
    static let cpuComplex = "Tp09"          // perf core (Apple Silicon)
    static let cpuComplexAlt = "TCXC"       // CPU complex (older/Intel)
    /// CPU proximity sensor
    static let cpuProximity = "TC0D"
    /// GPU die temperature
    static let gpuDie = "Tg05"              // GPU (Apple Silicon)
    static let gpuDieAlt = "TG0D"           // GPU (older models)
    /// Battery temperature
    static let batteryTemp = "TB1T"
    /// Ambient temperature
    static let ambientTemp = "TA0P"

    // MARK: - Power

    /// System power draw in watts
    static let systemWatts = "PSTR"

    // MARK: - Helpers

    /// Returns all key strings for temperature sensors
    static var temperatureSensors: [String] {
        [keyboardTemp, cpuComplex, cpuProximity, gpuDie, batteryTemp, ambientTemp]
    }

    /// Returns display name for a sensor key
    static func displayName(for key: String) -> String {
        switch key {
        case keyboardTemp: return "Keyboard"
        case cpuComplex: return "CPU Complex"
        case cpuProximity: return "CPU Proximity"
        case gpuDie: return "GPU"
        case batteryTemp: return "Battery"
        case ambientTemp: return "Ambient"
        default: return "Unknown"
        }
    }
}
