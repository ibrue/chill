import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct NewAppRuleView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedApp: URL?
    @State private var appName: String
    @State private var bundleID: String
    @State private var selectedProfileID: UUID?
    @State private var enabled: Bool

    private let existingRule: AppRule?
    private let profiles: [FanProfile]
    private let existingRules: [AppRule]
    private let onSave: (AppRule) -> Void

    init(
        existingRule: AppRule? = nil,
        profiles: [FanProfile] = FanProfile.allBuiltIn,
        existingRules: [AppRule] = [],
        onSave: @escaping (AppRule) -> Void
    ) {
        self.existingRule = existingRule
        self.profiles = profiles
        self.existingRules = existingRules
        self.onSave = onSave
        self._appName = State(initialValue: existingRule?.appName ?? "")
        self._bundleID = State(initialValue: existingRule?.bundleID ?? "")
        self._selectedProfileID = State(initialValue: existingRule?.profileID ?? profiles.first?.id)
        self._enabled = State(initialValue: existingRule?.enabled ?? true)
    }

    var body: some View {
        ZStack {
            ruleBackground

            VStack(alignment: .leading, spacing: 16) {
                header

                GlassCard(cornerRadius: 16, padding: 14) {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Application", systemImage: "app.badge")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))

                        if hasApp {
                            selectedAppRow
                        } else {
                            Button(action: pickApp) {
                                Label("Choose App...", systemImage: "folder.badge.plus")
                            }
                        }
                    }
                }

                GlassCard(cornerRadius: 16, padding: 14) {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Rule", systemImage: "switch.2")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))

                        Picker("Apply profile", selection: $selectedProfileID) {
                            ForEach(profiles) { profile in
                                Label(profile.name, systemImage: profile.sfSymbol)
                                    .tag(profile.id as UUID?)
                            }
                        }

                        Toggle("Enabled", isOn: $enabled)
                            .toggleStyle(.switch)

                        if let duplicateMessage {
                            Text(duplicateMessage)
                                .font(.caption)
                                .foregroundStyle(Brand.hot)
                        }
                    }
                }

                Spacer()

                HStack {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button(existingRule == nil ? "Add Rule" : "Save Rule", action: save)
                        .disabled(!canSave)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(18)
        }
        .frame(minWidth: 500, minHeight: 430)
    }

    private var ruleBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Brand.primary.opacity(0.16), Brand.secondary.opacity(0.08), .black.opacity(0.02)],
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(existingRule == nil ? "Add App Rule" : "Edit App Rule")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text("When this app is active, Chill temporarily applies the selected profile.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var selectedAppRow: some View {
        HStack(spacing: 12) {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(appName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(bundleID)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer()

            Button(action: pickApp) {
                Label("Change", systemImage: "arrow.triangle.2.circlepath")
            }
        }
    }

    private var hasApp: Bool {
        !appName.isEmpty && !bundleID.isEmpty
    }

    private var canSave: Bool {
        hasApp && selectedProfileID != nil && duplicateMessage == nil
    }

    private var duplicateMessage: String? {
        let duplicate = existingRules.contains { rule in
            rule.bundleID == bundleID && rule.id != existingRule?.id
        }
        return duplicate ? "A rule already exists for this app." : nil
    }

    private var appIcon: NSImage {
        if let selectedApp {
            return NSWorkspace.shared.icon(forFile: selectedApp.path)
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: UTType.applicationBundle)
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            selectedApp = url
            appName = url.lastPathComponent.replacingOccurrences(of: ".app", with: "")
            bundleID = Bundle(url: url)?.bundleIdentifier ?? appName
        }
    }

    private func save() {
        guard let selectedProfileID else { return }
        let rule = AppRule(
            id: existingRule?.id ?? UUID(),
            appName: appName,
            bundleID: bundleID,
            profileID: selectedProfileID,
            enabled: enabled
        )
        onSave(rule)
        dismiss()
    }
}

#Preview {
    NewAppRuleView { _ in }
}
