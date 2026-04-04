import Foundation

// MARK: - Curve Point

struct TempCurvePoint: Codable, Identifiable, Hashable {
    var id = UUID()
    var tempCelsius: Float
    var rpmPercent: Float  // 0.0 to 1.0

    init(temp: Float, rpmPercent: Float) {
        self.tempCelsius = temp
        self.rpmPercent = min(1.0, max(0.0, rpmPercent))
    }
}

// MARK: - Power Mode (for Adaptive profile)

enum PowerMode: String, Codable, CaseIterable {
    case lowPower = "Low Power"
    case balanced = "Balanced"
    case highPerformance = "High Performance"

    var sfSymbol: String {
        switch self {
        case .lowPower: return "battery.25percent"
        case .balanced: return "battery.75percent"
        case .highPerformance: return "bolt.fill"
        }
    }
}

// MARK: - Fan Profile

struct FanProfile: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var subtitle: String
    var description: String
    var sfSymbol: String
    var primarySensor: String    // SMC key (default: Ts0S)
    var fallbackSensors: [String]
    var curve: [TempCurvePoint]
    var hysteresisDegrees: Float  // Time in seconds before RPM drops
    var appTriggers: [String]    // Bundle IDs
    var isBuiltIn: Bool

    // Adaptive profile: power-mode-specific curves
    var adaptiveCurves: [String: [TempCurvePoint]]?  // PowerMode.rawValue -> curve

    var isAdaptive: Bool { adaptiveCurves != nil }

    /// Returns the curve for a given power mode, falling back to the default curve
    func curve(for powerMode: PowerMode) -> [TempCurvePoint] {
        adaptiveCurves?[powerMode.rawValue] ?? curve
    }

    init(
        id: UUID = UUID(),
        name: String,
        subtitle: String = "",
        description: String = "",
        sfSymbol: String,
        primarySensor: String = SMCKey.cpuComplex,
        fallbackSensors: [String] = [],
        curve: [TempCurvePoint],
        hysteresisDegrees: Float = 3.0,
        appTriggers: [String] = [],
        isBuiltIn: Bool = false,
        adaptiveCurves: [String: [TempCurvePoint]]? = nil
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.description = description
        self.sfSymbol = sfSymbol
        self.primarySensor = primarySensor
        self.fallbackSensors = fallbackSensors
        self.curve = curve
        self.hysteresisDegrees = hysteresisDegrees
        self.appTriggers = appTriggers
        self.isBuiltIn = isBuiltIn
        self.adaptiveCurves = adaptiveCurves
    }

    // MARK: - Built-in Profiles

    /// Auto mode - let thermalmonitord handle it
    static var auto: FanProfile {
        FanProfile(
            name: "Auto",
            subtitle: "System default",
            description: "Let macOS manage fan speed. Fans stay quiet until the system decides to ramp up.",
            sfSymbol: "leaf.fill",
            primarySensor: SMCKey.cpuComplex,
            curve: [
                TempCurvePoint(temp: 30, rpmPercent: 0.2),
                TempCurvePoint(temp: 50, rpmPercent: 0.3),
                TempCurvePoint(temp: 70, rpmPercent: 0.6),
                TempCurvePoint(temp: 90, rpmPercent: 1.0),
            ],
            isBuiltIn: true
        )
    }

    /// Balanced - sensible default for everyday use
    static var balanced: FanProfile {
        FanProfile(
            name: "Balanced",
            subtitle: "Everyday use",
            description: "A sensible middle ground. Triggers fans 8\u{00B0}C earlier than Apple for better sustained performance without noise.",
            sfSymbol: "gauge.medium",
            primarySensor: SMCKey.cpuComplex,
            curve: [
                TempCurvePoint(temp: 30, rpmPercent: 0.25),
                TempCurvePoint(temp: 45, rpmPercent: 0.40),
                TempCurvePoint(temp: 60, rpmPercent: 0.55),
                TempCurvePoint(temp: 75, rpmPercent: 0.75),
                TempCurvePoint(temp: 90, rpmPercent: 1.00),
            ],
            isBuiltIn: true
        )
    }

    /// Whisper - ultra-quiet, minimal fan activity
    static var whisper: FanProfile {
        FanProfile(
            name: "Whisper",
            subtitle: "Silent operation",
            description: "Prioritizes silence. Fans stay near minimum until temps get critical. Best for quiet environments.",
            sfSymbol: "moon.fill",
            primarySensor: SMCKey.cpuComplex,
            curve: [
                TempCurvePoint(temp: 30, rpmPercent: 0.15),
                TempCurvePoint(temp: 50, rpmPercent: 0.20),
                TempCurvePoint(temp: 70, rpmPercent: 0.40),
                TempCurvePoint(temp: 85, rpmPercent: 0.80),
                TempCurvePoint(temp: 95, rpmPercent: 1.00),
            ],
            hysteresisDegrees: 5.0,
            isBuiltIn: true
        )
    }

    /// Performance - maximum cooling for sustained loads
    static var performance: FanProfile {
        FanProfile(
            name: "Performance",
            subtitle: "Max cooling",
            description: "Aggressive fan ramp to prevent CPU throttling. Ideal for exports, compiles, and gaming.",
            sfSymbol: "bolt.fill",
            primarySensor: SMCKey.cpuComplex,
            curve: [
                TempCurvePoint(temp: 30, rpmPercent: 0.40),
                TempCurvePoint(temp: 45, rpmPercent: 0.60),
                TempCurvePoint(temp: 60, rpmPercent: 0.80),
                TempCurvePoint(temp: 75, rpmPercent: 0.95),
                TempCurvePoint(temp: 85, rpmPercent: 1.00),
            ],
            isBuiltIn: true
        )
    }

    /// Adaptive - automatically shifts fan curve based on power state
    static var adaptive: FanProfile {
        FanProfile(
            name: "Adaptive",
            subtitle: "Power-aware",
            description: "Automatically adjusts fan behavior based on your power state. Quiet on battery, aggressive when plugged in under load.",
            sfSymbol: "arrow.2.squarepath",
            primarySensor: SMCKey.cpuComplex,
            curve: [
                // Default/balanced curve (used as fallback)
                TempCurvePoint(temp: 30, rpmPercent: 0.25),
                TempCurvePoint(temp: 45, rpmPercent: 0.40),
                TempCurvePoint(temp: 60, rpmPercent: 0.55),
                TempCurvePoint(temp: 75, rpmPercent: 0.75),
                TempCurvePoint(temp: 90, rpmPercent: 1.00),
            ],
            isBuiltIn: true,
            adaptiveCurves: [
                PowerMode.lowPower.rawValue: [
                    TempCurvePoint(temp: 30, rpmPercent: 0.10),
                    TempCurvePoint(temp: 50, rpmPercent: 0.20),
                    TempCurvePoint(temp: 70, rpmPercent: 0.35),
                    TempCurvePoint(temp: 85, rpmPercent: 0.70),
                    TempCurvePoint(temp: 95, rpmPercent: 1.00),
                ],
                PowerMode.balanced.rawValue: [
                    TempCurvePoint(temp: 30, rpmPercent: 0.25),
                    TempCurvePoint(temp: 45, rpmPercent: 0.40),
                    TempCurvePoint(temp: 60, rpmPercent: 0.55),
                    TempCurvePoint(temp: 75, rpmPercent: 0.75),
                    TempCurvePoint(temp: 90, rpmPercent: 1.00),
                ],
                PowerMode.highPerformance.rawValue: [
                    TempCurvePoint(temp: 30, rpmPercent: 0.35),
                    TempCurvePoint(temp: 40, rpmPercent: 0.55),
                    TempCurvePoint(temp: 55, rpmPercent: 0.75),
                    TempCurvePoint(temp: 70, rpmPercent: 0.90),
                    TempCurvePoint(temp: 80, rpmPercent: 1.00),
                ],
            ]
        )
    }

    // MARK: - Persistence

    /// Load all built-in profiles
    static var allBuiltIn: [FanProfile] {
        [.auto, .adaptive, .balanced, .whisper, .performance]
    }

    /// Load a profile by ID
    static func load(withID id: UUID) -> FanProfile? {
        // Check built-in profiles first
        if let builtin = allBuiltIn.first(where: { $0.id == id }) {
            return builtin
        }

        // Check custom profiles in UserDefaults
        if let data = UserDefaults(suiteName: ChillConstants.suiteName)?.data(forKey: "profile_\(id)") {
            if let profile = try? JSONDecoder().decode(FanProfile.self, from: data) {
                return profile
            }
        }

        return nil
    }

    /// Save a custom profile (upserts into the shared customProfiles array)
    func save() {
        guard !isBuiltIn else { return }
        var profiles = FanProfile.allCustom()
        if let index = profiles.firstIndex(where: { $0.id == id }) {
            profiles[index] = self
        } else {
            profiles.append(self)
        }
        FanProfile.saveAllCustom(profiles)
    }

    /// Delete a profile
    static func delete(withID id: UUID) {
        var profiles = allCustom()
        profiles.removeAll { $0.id == id }
        saveAllCustom(profiles)
    }

    /// Get all custom profiles
    static func allCustom() -> [FanProfile] {
        if let data = UserDefaults(suiteName: ChillConstants.suiteName)?.data(forKey: "customProfiles") {
            if let profiles = try? JSONDecoder().decode([FanProfile].self, from: data) {
                return profiles
            }
        }
        return []
    }

    /// Persist the full custom profiles array
    private static func saveAllCustom(_ profiles: [FanProfile]) {
        if let encoded = try? JSONEncoder().encode(profiles) {
            UserDefaults(suiteName: ChillConstants.suiteName)?.set(encoded, forKey: "customProfiles")
        }
    }
}

// MARK: - Hashing and Equatable

extension FanProfile {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FanProfile, rhs: FanProfile) -> Bool {
        lhs.id == rhs.id
    }
}
