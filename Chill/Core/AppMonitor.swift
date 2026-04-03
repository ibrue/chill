import Foundation
import Observation
import AppKit

/// Monitors active app and triggers profiles based on rules
@Observable
final class AppMonitor {
    private var appRules: [AppRule] = []
    var currentTriggeredProfile: FanProfile?

    init() {
        loadAppRules()
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

    private func loadAppRules() {
        // Load from UserDefaults or on-disk storage
        if let data = UserDefaults(suiteName: ChillConstants.suiteName)?.data(forKey: "appRules") {
            if let decoded = try? JSONDecoder().decode([AppRule].self, from: data) {
                appRules = decoded
            }
        }
    }

    func saveAppRules(_ rules: [AppRule]) {
        appRules = rules
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults(suiteName: ChillConstants.suiteName)?.set(encoded, forKey: "appRules")
        }
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
        currentTriggeredProfile = nil
    }

    private func checkAndApplyRules(for bundleID: String) {
        // Find matching rule
        for rule in appRules {
            if rule.bundleID == bundleID {
                // Load the profile by ID
                if let profile = FanProfile.load(withID: rule.profileID) {
                    currentTriggeredProfile = profile
                    return
                }
            }
        }

        currentTriggeredProfile = nil
    }
}
