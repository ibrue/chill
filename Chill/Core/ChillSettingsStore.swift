import Foundation
import Observation

enum MenuBarDisplayMode: String, Codable, CaseIterable, Identifiable {
    case iconOnly
    case temperature
    case rpm
    case temperatureAndRPM

    var id: String { rawValue }

    var label: String {
        switch self {
        case .iconOnly: return "Icon Only"
        case .temperature: return "Temperature"
        case .rpm: return "RPM"
        case .temperatureAndRPM: return "Temperature + RPM"
        }
    }
}

@Observable
final class ChillSettingsStore {
    private enum Key {
        static let customProfiles = "customProfiles"
        static let appRules = "appRules"
        static let menuBarDisplayMode = "menuBarDisplayMode"
    }

    private let defaults = UserDefaults(suiteName: ChillConstants.suiteName) ?? .standard

    var customProfiles: [FanProfile] = []
    var appRules: [AppRule] = []
    var menuBarDisplayMode: MenuBarDisplayMode = .iconOnly {
        didSet {
            defaults.set(menuBarDisplayMode.rawValue, forKey: Key.menuBarDisplayMode)
        }
    }

    var allProfiles: [FanProfile] {
        FanProfile.allBuiltIn + customProfiles
    }

    init() {
        reload()
    }

    func reload() {
        customProfiles = Self.loadCustomProfiles(from: defaults)
        appRules = Self.loadAppRules(from: defaults)
        if let rawValue = defaults.string(forKey: Key.menuBarDisplayMode),
           let mode = MenuBarDisplayMode(rawValue: rawValue) {
            menuBarDisplayMode = mode
        }
    }

    func profile(withID id: UUID) -> FanProfile? {
        allProfiles.first { $0.id == id }
    }

    @discardableResult
    func saveProfile(_ profile: FanProfile) -> FanProfile {
        var saved = profile
        saved.isBuiltIn = false

        if let index = customProfiles.firstIndex(where: { $0.id == saved.id }) {
            customProfiles[index] = saved
        } else {
            customProfiles.append(saved)
        }

        persistProfiles()
        return saved
    }

    @discardableResult
    func duplicateProfile(_ profile: FanProfile) -> FanProfile {
        let baseName = profile.name.replacingOccurrences(of: " Copy", with: "")
        var copy = FanProfile(
            name: uniqueProfileName(baseName + " Copy"),
            sfSymbol: profile.sfSymbol,
            primarySensor: profile.primarySensor,
            fallbackSensors: profile.fallbackSensors,
            curve: profile.curve.map { TempCurvePoint(temp: $0.tempCelsius, rpmPercent: $0.rpmPercent) },
            hysteresisDegrees: profile.hysteresisDegrees,
            appTriggers: profile.appTriggers,
            isBuiltIn: false
        )
        copy.id = UUID()
        return saveProfile(copy)
    }

    func deleteProfile(_ profile: FanProfile) {
        guard !profile.isBuiltIn else { return }
        customProfiles.removeAll { $0.id == profile.id }
        defaults.removeObject(forKey: "profile_\(profile.id)")
        appRules.removeAll { $0.profileID == profile.id }
        persistProfiles()
        persistAppRules()
    }

    func saveRule(_ rule: AppRule) -> Bool {
        guard !hasRule(for: rule.bundleID, excluding: rule.id) else { return false }

        if let index = appRules.firstIndex(where: { $0.id == rule.id }) {
            appRules[index] = rule
        } else {
            appRules.append(rule)
        }

        persistAppRules()
        return true
    }

    func deleteRule(_ rule: AppRule) {
        appRules.removeAll { $0.id == rule.id }
        persistAppRules()
    }

    func setRule(_ rule: AppRule, enabled: Bool) {
        guard let index = appRules.firstIndex(where: { $0.id == rule.id }) else { return }
        appRules[index].enabled = enabled
        persistAppRules()
    }

    func hasRule(for bundleID: String, excluding id: UUID? = nil) -> Bool {
        appRules.contains { rule in
            rule.bundleID == bundleID && rule.id != id
        }
    }

    private func uniqueProfileName(_ proposed: String) -> String {
        let existing = Set(allProfiles.map(\.name))
        guard existing.contains(proposed) else { return proposed }

        for index in 2...99 {
            let candidate = "\(proposed) \(index)"
            if !existing.contains(candidate) {
                return candidate
            }
        }

        return "\(proposed) \(Int(Date().timeIntervalSince1970))"
    }

    private func persistProfiles() {
        if let encoded = try? JSONEncoder().encode(customProfiles) {
            defaults.set(encoded, forKey: Key.customProfiles)
        }

        for profile in customProfiles {
            if let encoded = try? JSONEncoder().encode(profile) {
                defaults.set(encoded, forKey: "profile_\(profile.id)")
            }
        }
    }

    private func persistAppRules() {
        if let encoded = try? JSONEncoder().encode(appRules) {
            defaults.set(encoded, forKey: Key.appRules)
        }
    }

    static func loadCustomProfiles(from defaults: UserDefaults = UserDefaults(suiteName: ChillConstants.suiteName) ?? .standard) -> [FanProfile] {
        guard let data = defaults.data(forKey: Key.customProfiles),
              let profiles = try? JSONDecoder().decode([FanProfile].self, from: data) else {
            return []
        }
        return profiles
    }

    static func loadAppRules(from defaults: UserDefaults = UserDefaults(suiteName: ChillConstants.suiteName) ?? .standard) -> [AppRule] {
        guard let data = defaults.data(forKey: Key.appRules),
              let rules = try? JSONDecoder().decode([AppRule].self, from: data) else {
            return []
        }
        return rules
    }
}
