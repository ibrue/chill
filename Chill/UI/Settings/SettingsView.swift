import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(ChillSettingsStore.self) private var settingsStore
    @Environment(SensorManager.self) private var sensorManager
    @Environment(FanController.self) private var fanController
    @Environment(ProfileEngine.self) private var profileEngine
    @Environment(PowerMonitor.self) private var powerMonitor
    @Environment(AppMonitor.self) private var appMonitor

    @State private var selectedTab: SettingsTab = .overview

    enum SettingsTab: String, CaseIterable, Hashable {
        case overview = "Overview"
        case general = "General"
        case profiles = "Profiles"
        case appRules = "App Rules"
        case diagnostics = "Diagnostics"

        var icon: String {
            switch self {
            case .overview: return "gauge.with.dots.needle.67percent"
            case .general: return "slider.horizontal.3"
            case .profiles: return "fan.fill"
            case .appRules: return "app.connected.to.app.below.fill"
            case .diagnostics: return "info.circle.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            settingsBackground
            HStack(spacing: 0) {
                sidebar
                Divider().opacity(0.25)
                detail
            }
        }
        .frame(minWidth: 820, minHeight: 560)
    }

    private var settingsBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Brand.primary.opacity(0.18), Brand.secondary.opacity(0.08), .black.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if #available(macOS 15, *) {
                Color.clear.background(.ultraThinMaterial)
            } else {
                VisualEffectView(material: .hudWindow)
            }
        }
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            BrandMark()
                .padding(.top, 18)
                .padding(.horizontal, 18)

            VStack(spacing: 6) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    SettingsTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            GlassCard(cornerRadius: 14, padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(fanController.isHelperConnected ? "Helper online" : "Helper offline", systemImage: fanController.isHelperConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(fanController.isHelperConnected ? Brand.calm : Brand.warm)
                    Text(profileEngine.activeProfile.name)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text(profileEngine.ruleOverrideProfile == nil ? "User selected" : "App rule active")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
        .frame(width: 210)
    }

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                pageHeader
                switch selectedTab {
                case .overview:
                    OverviewSettingsPage()
                case .general:
                    GeneralSettingsPage()
                case .profiles:
                    ProfilesSettingsPage()
                case .appRules:
                    AppRulesSettingsPage()
                case .diagnostics:
                    DiagnosticsSettingsPage()
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(selectedTab.rawValue, systemImage: selectedTab.icon)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
            Text(headerSubtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var headerSubtitle: String {
        switch selectedTab {
        case .overview: return "Live thermal state and quick profile switching."
        case .general: return "Menu bar behavior, startup, and everyday preferences."
        case .profiles: return "Preview built-ins and tune custom fan curves."
        case .appRules: return "Automatically switch profiles when specific apps are active."
        case .diagnostics: return "Build, helper, and recovery controls."
        }
    }
}

private struct SettingsTabButton: View {
    let tab: SettingsView.SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Brand.primary.opacity(0.22) : .clear)
            )
            .foregroundStyle(isSelected ? Brand.primary : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct OverviewSettingsPage: View {
    @Environment(SensorManager.self) private var sensorManager
    @Environment(FanController.self) private var fanController
    @Environment(ProfileEngine.self) private var profileEngine
    @Environment(PowerMonitor.self) private var powerMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                StatusMetricCard(title: "CPU", value: temp(sensorManager.cpuTemp), icon: "cpu", tint: Brand.tierColor(for: sensorManager.cpuTemp))
                StatusMetricCard(title: "GPU", value: temp(sensorManager.gpuTemp), icon: "memorychip", tint: Brand.tierColor(for: sensorManager.gpuTemp))
                StatusMetricCard(title: "Keyboard", value: temp(sensorManager.keyboardTemp), icon: "keyboard", tint: Brand.tierColor(for: sensorManager.keyboardTemp))
                StatusMetricCard(title: "Battery", value: temp(sensorManager.batteryTemp), icon: "battery.75", tint: Brand.tierColor(for: sensorManager.batteryTemp))
                StatusMetricCard(title: "Fan 0", value: rpm(sensorManager.fan0RPM), icon: "fan", tint: fanController.isManualMode ? Brand.warm : Brand.primary)
                StatusMetricCard(title: "Power", value: watts(sensorManager.systemWatts), icon: "bolt.fill", tint: Brand.warm)
            }

            GlassCard(cornerRadius: 16, padding: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Active Profile", systemImage: profileEngine.activeProfile.sfSymbol)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Spacer()
                        Text(profileEngine.ruleOverrideProfile == nil ? "Manual selection" : "App rule override")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    FanCurveChart(curve: profileEngine.activeProfile.curve, currentTemp: sensorManager.cpuTemp)
                        .frame(height: 150)

                    HStack(spacing: 8) {
                        ForEach(FanProfile.allBuiltIn) { profile in
                            ProfilePill(
                                profile: profile,
                                isSelected: profileEngine.selectedProfile.id == profile.id && profileEngine.ruleOverrideProfile == nil,
                                action: { profileEngine.switchProfile(profile) }
                            )
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                StatusMetricCard(title: "Helper", value: fanController.isHelperConnected ? "Online" : "Offline", icon: fanController.isHelperConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill", tint: fanController.isHelperConnected ? Brand.calm : Brand.hot)
                StatusMetricCard(title: "Power Source", value: powerMonitor.isOnAC ? "AC" : "\(powerMonitor.batteryPercent)%", icon: powerMonitor.isOnAC ? "powerplug.fill" : "battery.75", tint: powerMonitor.isOnAC ? Brand.primary : Brand.calm)
            }
        }
    }

    private func temp(_ value: Float) -> String {
        value > 0 ? "\(Int(value.rounded()))°C" : "—"
    }

    private func rpm(_ value: Float) -> String {
        value > 0 ? "\(Int(value.rounded())) RPM" : "—"
    }

    private func watts(_ value: Float) -> String {
        value > 0 ? String(format: "%.1f W", value) : "—"
    }
}

private struct GeneralSettingsPage: View {
    @Environment(ChillSettingsStore.self) private var settingsStore
    @State private var launchAtLoginEnabled = false
    @State private var launchStatusText = "Checking..."
    @State private var launchError: String?

    var body: some View {
        let store = settingsStore

        VStack(alignment: .leading, spacing: 14) {
            GlassCard(cornerRadius: 16, padding: 14) {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsSectionTitle(icon: "power", title: "Startup", detail: launchStatusText)

                    Toggle("Launch Chill at login", isOn: Binding(
                        get: { launchAtLoginEnabled },
                        set: { setLaunchAtLogin($0) }
                    ))
                    .toggleStyle(.switch)

                    if let launchError {
                        Text(launchError)
                            .font(.caption)
                            .foregroundStyle(Brand.hot)
                    }
                }
            }

            GlassCard(cornerRadius: 16, padding: 14) {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsSectionTitle(icon: "menubar.rectangle", title: "Menu Bar", detail: "Choose what Chill shows next to the tray icon.")

                    Picker("Menu bar display", selection: Bindable(store).menuBarDisplayMode) {
                        ForEach(MenuBarDisplayMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .onAppear(perform: refreshLaunchAtLogin)
    }

    private func refreshLaunchAtLogin() {
        let status = SMAppService.mainApp.status
        launchAtLoginEnabled = status == .enabled
        switch status {
        case .enabled:
            launchStatusText = "Enabled"
        case .requiresApproval:
            launchStatusText = "Requires approval in System Settings"
        case .notRegistered:
            launchStatusText = "Not enabled"
        case .notFound:
            launchStatusText = "App service not found"
        @unknown default:
            launchStatusText = "Unknown"
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchError = nil
        } catch {
            launchError = error.localizedDescription
        }
        refreshLaunchAtLogin()
    }
}

private struct ProfilesSettingsPage: View {
    @Environment(ChillSettingsStore.self) private var settingsStore
    @Environment(ProfileEngine.self) private var profileEngine
    @Environment(AppMonitor.self) private var appMonitor

    @State private var editingProfile: FanProfile?
    @State private var previewProfile: FanProfile?
    @State private var isCreatingProfile = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Built-ins")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer()
                Button(action: { isCreatingProfile = true }) {
                    Label("New Profile", systemImage: "plus")
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
                ForEach(FanProfile.allBuiltIn) { profile in
                    ProfileCard(
                        profile: profile,
                        isActive: profileEngine.activeProfile.id == profile.id,
                        badge: "Built-in",
                        primaryActionTitle: "Preview",
                        primaryAction: { previewProfile = profile },
                        secondaryActionTitle: "Duplicate",
                        secondaryAction: {
                            editingProfile = settingsStore.duplicateProfile(profile)
                            appMonitor.reloadRulesAndEvaluate()
                        }
                    )
                }
            }

            Text("Custom")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .padding(.top, 4)

            if settingsStore.customProfiles.isEmpty {
                EmptyStateCard(icon: "slider.horizontal.below.fan", title: "No custom profiles yet", detail: "Duplicate a built-in profile or create a new curve.")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
                    ForEach(settingsStore.customProfiles) { profile in
                        ProfileCard(
                            profile: profile,
                            isActive: profileEngine.activeProfile.id == profile.id,
                            badge: "Custom",
                            primaryActionTitle: "Edit",
                            primaryAction: { editingProfile = profile },
                            secondaryActionTitle: "Duplicate",
                            secondaryAction: {
                                editingProfile = settingsStore.duplicateProfile(profile)
                                appMonitor.reloadRulesAndEvaluate()
                            },
                            destructiveActionTitle: "Delete",
                            destructiveAction: {
                                settingsStore.deleteProfile(profile)
                                if profileEngine.selectedProfile.id == profile.id {
                                    profileEngine.switchProfile(.auto)
                                }
                                appMonitor.reloadRulesAndEvaluate()
                            }
                        )
                    }
                }
            }
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditorView(profile: profile) { saved in
                _ = settingsStore.saveProfile(saved)
                appMonitor.reloadRulesAndEvaluate()
            }
        }
        .sheet(item: $previewProfile) { profile in
            ProfileEditorView(profile: profile, isReadOnly: true)
        }
        .sheet(isPresented: $isCreatingProfile) {
            ProfileEditorView(profile: FanProfile(
                name: "Custom Profile",
                sfSymbol: "fan.fill",
                curve: [
                    TempCurvePoint(temp: 40, rpmPercent: 0.30),
                    TempCurvePoint(temp: 70, rpmPercent: 0.70),
                    TempCurvePoint(temp: 90, rpmPercent: 1.00),
                ]
            )) { saved in
                _ = settingsStore.saveProfile(saved)
                appMonitor.reloadRulesAndEvaluate()
            }
        }
    }
}

private struct AppRulesSettingsPage: View {
    @Environment(ChillSettingsStore.self) private var settingsStore
    @Environment(AppMonitor.self) private var appMonitor

    @State private var editingRule: AppRule?
    @State private var isAddingRule = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Rules")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer()
                Button(action: { isAddingRule = true }) {
                    Label("Add Rule", systemImage: "plus")
                }
            }

            if settingsStore.appRules.isEmpty {
                EmptyStateCard(icon: "app.badge", title: "No app rules yet", detail: "Add an app to make Chill switch profiles automatically while that app is active.")
            } else {
                VStack(spacing: 10) {
                    ForEach(settingsStore.appRules) { rule in
                        AppRuleRow(
                            rule: rule,
                            profile: settingsStore.profile(withID: rule.profileID),
                            onToggle: { enabled in
                                settingsStore.setRule(rule, enabled: enabled)
                                appMonitor.reloadRulesAndEvaluate()
                            },
                            onEdit: { editingRule = rule },
                            onDelete: {
                                settingsStore.deleteRule(rule)
                                appMonitor.reloadRulesAndEvaluate()
                            }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingRule) {
            NewAppRuleView(
                profiles: settingsStore.allProfiles,
                existingRules: settingsStore.appRules,
                onSave: saveRule
            )
        }
        .sheet(item: $editingRule) { rule in
            NewAppRuleView(
                existingRule: rule,
                profiles: settingsStore.allProfiles,
                existingRules: settingsStore.appRules,
                onSave: saveRule
            )
        }
    }

    private func saveRule(_ rule: AppRule) {
        _ = settingsStore.saveRule(rule)
        appMonitor.reloadRulesAndEvaluate()
    }
}

private struct DiagnosticsSettingsPage: View {
    @Environment(FanController.self) private var fanController
    @Environment(ProfileEngine.self) private var profileEngine

    @State private var resetMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassCard(cornerRadius: 16, padding: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsSectionTitle(icon: "info.circle.fill", title: "About Chill", detail: Brand.tagline)
                    InfoRow(label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    InfoRow(label: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Debug")
                    InfoRow(label: "Bundle", value: Bundle.main.bundleIdentifier ?? ChillConstants.appBundleID)
                }
            }

            GlassCard(cornerRadius: 16, padding: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsSectionTitle(icon: "wrench.and.screwdriver.fill", title: "Recovery", detail: fanController.isHelperConnected ? "Helper is connected." : "Helper is not connected.")

                    HStack(spacing: 10) {
                        Button {
                            fanController.setAutoMode { success in
                                profileEngine.switchProfile(.auto)
                                resetMessage = success ? "Fans returned to Auto." : "Could not reach helper."
                            }
                        } label: {
                            Label("Reset Fans to Auto", systemImage: "arrow.counterclockwise")
                        }

                        if let diagnosticsURL {
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([diagnosticsURL])
                            } label: {
                                Label("Reveal Diagnostics", systemImage: "doc.text.magnifyingglass")
                            }
                        }
                    }

                    if let resetMessage {
                        Text(resetMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var diagnosticsURL: URL? {
        let candidates = [
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Logs/Chill"),
            URL(fileURLWithPath: "/tmp/chill-release-smoke.log"),
            URL(fileURLWithPath: "/tmp/chill-icon-smoke.log"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}

private struct ProfileCard: View {
    let profile: FanProfile
    let isActive: Bool
    let badge: String
    let primaryActionTitle: String
    let primaryAction: () -> Void
    let secondaryActionTitle: String
    let secondaryAction: () -> Void
    var destructiveActionTitle: String?
    var destructiveAction: (() -> Void)?

    var body: some View {
        GlassCard(cornerRadius: 16, padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(profile.name, systemImage: profile.sfSymbol)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Spacer()
                    Text(isActive ? "Active" : badge)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill((isActive ? Brand.primary : .white).opacity(0.18)))
                }

                FanCurveChart(curve: profile.curve, currentTemp: 0)
                    .frame(height: 92)

                HStack(spacing: 8) {
                    Button(primaryActionTitle, action: primaryAction)
                    Button(secondaryActionTitle, action: secondaryAction)
                    Spacer()
                    if let destructiveActionTitle, let destructiveAction {
                        Button(destructiveActionTitle, role: .destructive, action: destructiveAction)
                    }
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

private struct AppRuleRow: View {
    let rule: AppRule
    let profile: FanProfile?
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GlassCard(cornerRadius: 14, padding: 12) {
            HStack(spacing: 12) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(rule.appName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(rule.bundleID)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let profile {
                    Label(profile.name, systemImage: profile.sfSymbol)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Brand.primary)
                } else {
                    Text("Missing profile")
                        .font(.caption)
                        .foregroundStyle(Brand.hot)
                }

                Toggle("", isOn: Binding(get: { rule.enabled }, set: onToggle))
                    .toggleStyle(.switch)
                    .labelsHidden()

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Edit rule")

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete rule")
            }
        }
    }

    private var appIcon: NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: UTType.applicationBundle)
    }
}

private struct StatusMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        GlassCard(cornerRadius: 15, padding: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct SettingsSectionTitle: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Brand.primary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct EmptyStateCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        GlassCard(cornerRadius: 16, padding: 18) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Brand.primary)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .textSelection(.enabled)
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
    }
}

#Preview {
    SettingsView()
        .environment(ChillSettingsStore())
        .environment(SensorManager())
        .environment(FanController())
        .environment(ProfileEngine())
        .environment(PowerMonitor())
        .environment(AppMonitor(settingsStore: ChillSettingsStore(), profileEngine: ProfileEngine()))
}
