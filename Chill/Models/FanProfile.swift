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

    /// macOS default reference curve. Used as the baseline for the offset profiles below.
    private static let autoCurve: [TempCurvePoint] = [
        TempCurvePoint(temp: 30, rpmPercent: 0.2),
        TempCurvePoint(temp: 50, rpmPercent: 0.3),
        TempCurvePoint(temp: 70, rpmPercent: 0.6),
        TempCurvePoint(temp: 90, rpmPercent: 1.0),
    ]

    /// Returns `base` with every trigger temperature shifted earlier by `offsetC` °C.
    private static func shifted(_ base: [TempCurvePoint], by offsetC: Float) -> [TempCurvePoint] {
        base.map { TempCurvePoint(temp: $0.tempCelsius - offsetC, rpmPercent: $0.rpmPercent) }
    }

    /// Auto - pass-through, mirrors thermalmonitord
    static let auto = FanProfile(
        name: "Auto",
        sfSymbol: "leaf.fill",
        primarySensor: SMCKey.cpuComplex,
        curve: autoCurve,
        isBuiltIn: true
    )

    /// Chill 4° - macOS default curve, ramps 4°C earlier
    static let chill4 = FanProfile(
        name: "Chill 4°",
        sfSymbol: "snowflake",
        primarySensor: SMCKey.cpuComplex,
        curve: shifted(autoCurve, by: 4),
        isBuiltIn: true
    )

    /// Chill 8° - macOS default curve, ramps 8°C earlier
    static let chill8 = FanProfile(
        name: "Chill 8°",
        sfSymbol: "snowflake.circle.fill",
        primarySensor: SMCKey.cpuComplex,
        curve: shifted(autoCurve, by: 8),
        isBuiltIn: true
    )

    /// Performance - aggressive ramp, prevents throttle under sustained load
    static let performance = FanProfile(
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

    // MARK: - Persistence

    /// Load all built-in profiles
    static var allBuiltIn: [FanProfile] {
        [.auto, .chill4, .chill8, .performance]
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
