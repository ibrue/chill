import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case profiles = "Profiles"
        case appRules = "App Rules"
        case about = "About"

        var icon: String {
            switch self {
            case .general: return "gear"
            case .profiles: return "fan.fill"
            case .appRules: return "app.connected.to.app.below.fill"
            case .about: return "info.circle.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .bold, design: .rounded))

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Tab bar
            HStack(spacing: 6) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 10))
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)
                        )
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 16)

            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsView()
                    case .profiles:
                        ProfilesSettingsView()
                    case .appRules:
                        AppRulesSettingsView()
                    case .about:
                        AboutSettingsView()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .frame(width: 380, height: 480)
    }
}

// MARK: - Card Container

struct SettingsCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(iconColor.opacity(0.12))
                )

            Text(label)
                .font(.system(size: 13, weight: .regular, design: .rounded))

            Spacer()
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("showRpmInMenuBar") var showRpmInMenuBar = false
    @AppStorage("thermalNotifications") var thermalNotifications = true

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard("Startup") {
                SettingsToggleRow(icon: "sunrise.fill", iconColor: .orange, label: "Launch at Login", isOn: $launchAtLogin)
            }

            SettingsCard("Menu Bar") {
                SettingsToggleRow(icon: "gauge.with.dots.needle.33percent", iconColor: .cyan, label: "Show RPM in Menu Bar", isOn: $showRpmInMenuBar)
            }

            SettingsCard("Notifications") {
                SettingsToggleRow(icon: "exclamationmark.triangle.fill", iconColor: .red, label: "Thermal Throttle Alerts", isOn: $thermalNotifications)
            }
        }
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(iconColor.opacity(0.12))
                )

            Text(label)
                .font(.system(size: 13, weight: .regular, design: .rounded))

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

// MARK: - Profiles Settings

struct ProfilesSettingsView: View {
    @State private var customProfiles = FanProfile.allCustom()
    @State private var showAddProfile = false

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard("Built-in Profiles") {
                VStack(spacing: 0) {
                    ForEach(Array(FanProfile.allBuiltIn.enumerated()), id: \.element.id) { index, profile in
                        if index > 0 {
                            Divider().padding(.vertical, 6)
                        }
                        ProfileSettingsRow(profile: profile)
                    }
                }
            }

            SettingsCard("Custom Profiles") {
                if customProfiles.isEmpty {
                    HStack {
                        Text("No custom profiles yet")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(customProfiles.enumerated()), id: \.element.id) { index, profile in
                            if index > 0 {
                                Divider().padding(.vertical, 6)
                            }
                            HStack(spacing: 10) {
                                ProfileSettingsRow(profile: profile)

                                Button(action: {
                                    FanProfile.delete(withID: profile.id)
                                    customProfiles.removeAll { $0.id == profile.id }
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.red.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            Button(action: { showAddProfile = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                    Text("New Profile")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showAddProfile) {
                NewProfileView { newProfile in
                    customProfiles.append(newProfile)
                    newProfile.save()
                }
            }
        }
    }
}

struct ProfileSettingsRow: View {
    let profile: FanProfile

    private var accentColor: Color {
        switch profile.name {
        case "Auto": return .green
        case "Adaptive": return .teal
        case "Balanced": return .blue
        case "Whisper": return .purple
        case "Performance": return .orange
        default: return .blue
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: profile.sfSymbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(accentColor)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(accentColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                Text(profile.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            MiniCurve(curve: profile.curve, accentColor: accentColor)
                .frame(width: 40, height: 18)
                .opacity(0.6)

            if profile.isBuiltIn {
                Text("Built-in")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.gray.opacity(0.1))
                    )
            }
        }
    }
}

// MARK: - App Rules Settings

struct AppRulesSettingsView: View {
    @State private var appRules: [AppRule] = []
    @State private var showAddRule = false

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard("Active Rules") {
                if appRules.isEmpty {
                    HStack {
                        Text("No app rules configured")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(appRules.enumerated()), id: \.element.id) { index, rule in
                            if index > 0 {
                                Divider().padding(.vertical, 6)
                            }
                            HStack(spacing: 10) {
                                Image(systemName: "app.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.blue)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.blue.opacity(0.12))
                                    )

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(rule.appName)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                    Text(rule.bundleID)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if let profile = FanProfile.load(withID: rule.profileID) {
                                    Text(profile.name)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule().fill(Color.gray.opacity(0.1))
                                        )
                                }

                                Button(action: {
                                    appRules.removeAll { $0.id == rule.id }
                                    saveAppRules(appRules)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.red.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            SettingsCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                        Text("How it works")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    Text("When a matched app becomes frontmost, Chill automatically switches to its assigned fan profile. When you switch away, it returns to your previously selected profile.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: { showAddRule = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                    Text("Add App Rule")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showAddRule) {
                NewAppRuleView { newRule in
                    appRules.append(newRule)
                    saveAppRules(appRules)
                }
            }
        }
        .onAppear {
            appRules = loadAppRules()
        }
    }

    private func loadAppRules() -> [AppRule] {
        if let data = UserDefaults(suiteName: ChillConstants.suiteName)?.data(forKey: "appRules") {
            if let rules = try? JSONDecoder().decode([AppRule].self, from: data) {
                return rules
            }
        }
        return []
    }

    private func saveAppRules(_ rules: [AppRule]) {
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults(suiteName: ChillConstants.suiteName)?.set(encoded, forKey: "appRules")
        }
    }
}

// MARK: - About Settings

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 14) {
            // App identity
            VStack(spacing: 8) {
                Image(systemName: "snowflake")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.cyan)

                Text("Chill")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text("Smart fan control for Apple Silicon")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)

            SettingsCard("Info") {
                VStack(spacing: 0) {
                    aboutRow(label: "Version", value: "1.0.0")
                    Divider().padding(.vertical, 6)
                    aboutRow(label: "Runtime", value: "Native SwiftUI")
                    Divider().padding(.vertical, 6)
                    aboutRow(label: "Requires", value: "macOS 14+, Apple Silicon")
                }
            }

            SettingsCard("Components") {
                VStack(spacing: 0) {
                    aboutRow(label: "Main App", value: "com.chill.app")
                    Divider().padding(.vertical, 6)
                    aboutRow(label: "Helper Daemon", value: "com.chill.helper")
                }
            }
        }
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    SettingsView()
}
