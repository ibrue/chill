import Foundation
import Observation
import AppKit

/// Monitors active app and triggers profiles based on rules
@Observable
final class AppMonitor {
    private let settingsStore: ChillSettingsStore
    private let profileEngine: ProfileEngine
    private var appRules: [AppRule] = []
    var currentTriggeredProfile: FanProfile?

    init(settingsStore: ChillSettingsStore, profileEngine: ProfileEngine) {
        self.settingsStore = settingsStore
        self.profileEngine = profileEngine
        reloadRules()
        setupNotifications()
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Setup

    private func setupNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidDeactivate),
            name: NSWorkspace.didDeactivateApplicationNotification,
            object: nil
        )
    }

    // MARK: - Rule Management

    func reloadRules() {
        appRules = settingsStore.appRules
    }

    func reloadRulesAndEvaluate() {
        reloadRules()
        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
            checkAndApplyRules(for: bundleID)
        } else {
            clearRuleOverride()
        }
    }

    func saveAppRules(_ rules: [AppRule]) {
        for rule in rules {
            _ = settingsStore.saveRule(rule)
        }
        reloadRulesAndEvaluate()
    }

    // MARK: - App Monitoring

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        let bundleID = app.bundleIdentifier ?? ""
        checkAndApplyRules(for: bundleID)
    }

    @objc private func appDidDeactivate(_ notification: Notification) {
        if NSWorkspace.shared.frontmostApplication == nil {
            clearRuleOverride()
        }
    }

    private func checkAndApplyRules(for bundleID: String) {
        // Find matching rule
        for rule in appRules {
            if rule.enabled && rule.bundleID == bundleID {
                // Load the profile by ID
                if let profile = settingsStore.profile(withID: rule.profileID) ?? FanProfile.load(withID: rule.profileID) {
                    currentTriggeredProfile = profile
                    profileEngine.applyRuleOverride(profile)
                    return
                }
            }
        }

        clearRuleOverride()
    }

    private func clearRuleOverride() {
        currentTriggeredProfile = nil
        profileEngine.applyRuleOverride(nil)
    }
}
