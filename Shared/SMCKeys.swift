import Foundation

/// SMC key constants for Apple Silicon Macs
enum SMCKey {
    // MARK: - Fan Control

    /// Unlock flag for fan control (Ftst=1 suppresses thermalmonitord)
    static let ftst = "Ftst"

    // Fan 0 (primary/larger)
    static let fanMode0 = "F0Md"
    static let fanTarget0 = "F0Tg"
    static let fanActual0 = "F0Ac"
    static let fanMin0 = "F0Mn"
    static let fanMax0 = "F0Mx"

    // Fan 1 (secondary/smaller)
    static let fanMode1 = "F1Md"
    static let fanTarget1 = "F1Tg"
    static let fanActual1 = "F1Ac"
    static let fanMin1 = "F1Mn"
    static let fanMax1 = "F1Mx"

    /// Number of fans
    static let fanCount = "FNum"

    // MARK: - Temperature Sensors
    //
    // Keys vary by Mac generation. The primaries below target current
    // Apple Silicon (M-series); the *Alt fallbacks cover older M1/Intel keys.
    // The helper tries primary first, then *Alt, and reports the result under
    // the primary key name.

    /// Keyboard / palm rest temperature
    static let keyboardTemp    = "Ts0P"
    static let keyboardTempAlt = "Ts0S"

    /// CPU temperature (perf core on Apple Silicon, complex on Intel)
    static let cpuComplex      = "Tp09"
    static let cpuComplexAlt   = "TCXC"

    /// CPU proximity sensor
    static let cpuProximity    = "TC0D"

    /// GPU die temperature
    static let gpuDie          = "Tg05"
    static let gpuDieAlt       = "TG0D"

    /// Battery temperature
    static let batteryTemp     = "TB1T"

    /// Ambient temperature
    static let ambientTemp     = "TA0P"

    // MARK: - Power

    /// System power draw in watts
    static let systemWatts = "PSTR"

    // MARK: - Helpers

    /// Sensors the helper should read on each poll, paired with optional fallback.
    /// The reported value comes back under the primary key.
    static var temperatureSensors: [(primary: String, fallback: String?)] {
        [
            (keyboardTemp, keyboardTempAlt),
            (cpuComplex,   cpuComplexAlt),
            (cpuProximity, nil),
            (gpuDie,       gpuDieAlt),
            (batteryTemp,  nil),
            (ambientTemp,  nil),
        ]
    }

    /// Just the primary key names — for UI pickers and profile editors that
    /// don't need to know about fallbacks.
    static var primaryTemperatureKeys: [String] {
        temperatureSensors.map { $0.primary }
    }

    static func displayName(for key: String) -> String {
        switch key {
        case keyboardTemp, keyboardTempAlt: return "Keyboard"
        case cpuComplex, cpuComplexAlt:     return "CPU"
        case cpuProximity:                  return "CPU Proximity"
        case gpuDie, gpuDieAlt:             return "GPU"
        case batteryTemp:                   return "Battery"
        case ambientTemp:                   return "Ambient"
        default: return "Unknown"
        }
    }
}
