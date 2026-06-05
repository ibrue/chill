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

    private enum BuiltInID {
        static let auto = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        static let chill4 = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
        static let chill8 = UUID(uuidString: "10000000-0000-0000-0000-000000000008")!
        static let performance = UUID(uuidString: "10000000-0000-0000-0000-0000000000FF")!
    }

    private static let autoCurve = [
        TempCurvePoint(temp: 30, rpmPercent: 0.2),
        TempCurvePoint(temp: 50, rpmPercent: 0.3),
        TempCurvePoint(temp: 70, rpmPercent: 0.6),
        TempCurvePoint(temp: 90, rpmPercent: 1.0),
    ]

    private static let performanceCurve = [
        TempCurvePoint(temp: 30, rpmPercent: 0.40),
        TempCurvePoint(temp: 45, rpmPercent: 0.60),
        TempCurvePoint(temp: 60, rpmPercent: 0.80),
        TempCurvePoint(temp: 75, rpmPercent: 0.95),
        TempCurvePoint(temp: 85, rpmPercent: 1.00),
    ]

    private static func shifted(_ base: [TempCurvePoint], by offsetC: Float) -> [TempCurvePoint] {
        base.map { TempCurvePoint(temp: $0.tempCelsius - offsetC, rpmPercent: $0.rpmPercent) }
    }

    /// Auto mode - let thermalmonitord handle it
    static var auto: FanProfile {
        FanProfile(
            id: BuiltInID.auto,
            name: "Auto",
            sfSymbol: "leaf.fill",
            primarySensor: SMCKey.cpuComplex,
            curve: autoCurve,
            isBuiltIn: true
        )
    }

    /// Chill 4° - Apple-default curve shifted 4°C earlier
    static var chill4: FanProfile {
        FanProfile(
            id: BuiltInID.chill4,
            name: "Chill 4°",
            sfSymbol: "snowflake",
            primarySensor: SMCKey.cpuComplex,
            curve: shifted(autoCurve, by: 4),
            isBuiltIn: true
        )
    }

    /// Chill 8° - Apple-default curve shifted 8°C earlier
    static var chill8: FanProfile {
        FanProfile(
            id: BuiltInID.chill8,
            name: "Chill 8°",
            sfSymbol: "snowflake.circle.fill",
            primarySensor: SMCKey.cpuComplex,
            curve: shifted(autoCurve, by: 8),
            isBuiltIn: true
        )
    }

    /// Performance - maximum cooling for sustained loads
    static var performance: FanProfile {
        FanProfile(
            id: BuiltInID.performance,
            name: "Performance",
            sfSymbol: "bolt.fill",
            primarySensor: SMCKey.cpuComplex,
            curve: performanceCurve,
            isBuiltIn: true
        )
    }

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
        if let profile = allCustom().first(where: { $0.id == id }) {
            return profile
        }

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
            let defaults = UserDefaults(suiteName: ChillConstants.suiteName)
            var profiles = Self.allCustom()
            if let index = profiles.firstIndex(where: { $0.id == id }) {
                profiles[index] = self
            } else {
                profiles.append(self)
            }

            if let encodedProfiles = try? JSONEncoder().encode(profiles) {
                defaults?.set(encodedProfiles, forKey: "customProfiles")
            }

            if let encodedProfile = try? JSONEncoder().encode(self) {
                defaults?.set(encodedProfile, forKey: "profile_\(id)")
            }
        }
    }

    /// Delete a profile
    static func delete(withID id: UUID) {
        let defaults = UserDefaults(suiteName: ChillConstants.suiteName)
        defaults?.removeObject(forKey: "profile_\(id)")
        let profiles = allCustom().filter { $0.id != id }
        if let encoded = try? JSONEncoder().encode(profiles) {
            defaults?.set(encoded, forKey: "customProfiles")
        }
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
