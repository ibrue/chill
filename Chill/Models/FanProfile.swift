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

// MARK: - Fan Profile

struct FanProfile: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var sfSymbol: String
    var primarySensor: String    // SMC key (default: Ts0S)
    var fallbackSensors: [String]
    var curve: [TempCurvePoint]
    var hysteresisDegrees: Float  // Time in seconds before RPM drops
    var appTriggers: [String]    // Bundle IDs
    var isBuiltIn: Bool

    init(
        id: UUID = UUID(),
        name: String,
        sfSymbol: String,
        primarySensor: String = SMCKey.cpuComplex,
        fallbackSensors: [String] = [],
        curve: [TempCurvePoint],
        hysteresisDegrees: Float = 3.0,
        appTriggers: [String] = [],
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.sfSymbol = sfSymbol
        self.primarySensor = primarySensor
        self.fallbackSensors = fallbackSensors
        self.curve = curve
        self.hysteresisDegrees = hysteresisDegrees
        self.appTriggers = appTriggers
        self.isBuiltIn = isBuiltIn
    }

    // MARK: - Built-in Profiles

    /// Auto mode - let thermalmonitord handle it
    static var auto: FanProfile {
        FanProfile(
            name: "Auto",
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

    /// Cool Keys - aggressive keyboard sensor monitoring
    /// Ramps up early to keep palm rest cool during typing
    static var coolKeys: FanProfile {
        FanProfile(
            name: "Cool Keys",
            sfSymbol: "keyboard.fill",
            primarySensor: SMCKey.keyboardTemp,
            fallbackSensors: [SMCKey.cpuComplex],
            curve: [
                TempCurvePoint(temp: 35, rpmPercent: 0.30),
                TempCurvePoint(temp: 40, rpmPercent: 0.55),
                TempCurvePoint(temp: 45, rpmPercent: 0.80),
                TempCurvePoint(temp: 50, rpmPercent: 1.00),
            ],
            hysteresisDegrees: 2.0,
            isBuiltIn: true
        )
    }

    /// Balanced - sensible default for everyday use
    static var balanced: FanProfile {
        FanProfile(
            name: "Balanced",
            sfSymbol: "gauge",
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

    // MARK: - Persistence

    /// Load all built-in profiles
    static var allBuiltIn: [FanProfile] {
        [.auto, .coolKeys, .balanced, .whisper, .performance]
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

    /// Save a custom profile
    func save() {
        if !isBuiltIn {
            if let encoded = try? JSONEncoder().encode(self) {
                UserDefaults(suiteName: ChillConstants.suiteName)?.set(encoded, forKey: "profile_\(id)")
            }
        }
    }

    /// Delete a profile
    static func delete(withID id: UUID) {
        UserDefaults(suiteName: ChillConstants.suiteName)?.removeObject(forKey: "profile_\(id)")
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
