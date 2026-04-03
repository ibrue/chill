import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: Hashable {
        case general, profiles, appRules, about
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label("General", systemImage: "gear")
                    .tag(SettingsTab.general)

                Label("Profiles", systemImage: "fan.fill")
                    .tag(SettingsTab.profiles)

                Label("App Rules", systemImage: "app.connected.to.app.below.fill")
                    .tag(SettingsTab.appRules)

                Label("About", systemImage: "info.circle.fill")
                    .tag(SettingsTab.about)
            }
            .listStyle(.sidebar)
        } detail: {
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
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("showRpmInMenuBar") var showRpmInMenuBar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Launch at Login", isOn: $launchAtLogin)

                Toggle("Show RPM in Menu Bar", isOn: $showRpmInMenuBar)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Profiles Settings

struct ProfilesSettingsView: View {
    @State private var customProfiles = FanProfile.allCustom()
    @State private var showAddProfile = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Profiles")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { showAddProfile = true }) {
                    Label("Add Profile", systemImage: "plus.circle.fill")
                }
            }

            List {
                Section("Built-in") {
                    ForEach(FanProfile.allBuiltIn) { profile in
                        HStack {
                            Image(systemName: profile.sfSymbol)
                            Text(profile.name)
                            Spacer()
                            Text("Built-in")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Custom") {
                    ForEach(customProfiles) { profile in
                        NavigationLink(destination: ProfileEditorView(profile: profile)) {
                            HStack {
                                Image(systemName: profile.sfSymbol)
                                Text(profile.name)
                                Spacer()
                            }
                        }
                    }
                    .onDelete(perform: deleteProfile)
                }
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showAddProfile) {
            NewProfileView { newProfile in
                customProfiles.append(newProfile)
                newProfile.save()
            }
        }
    }

    private func deleteProfile(at offsets: IndexSet) {
        for index in offsets {
            let profile = customProfiles[index]
            FanProfile.delete(withID: profile.id)
        }
        customProfiles.remove(atOffsets: offsets)
    }
}

// MARK: - App Rules Settings

struct AppRulesSettingsView: View {
    @State private var appRules: [AppRule] = []
    @State private var showAddRule = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("App Rules")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { showAddRule = true }) {
                    Label("Add Rule", systemImage: "plus.circle.fill")
                }
            }

            List {
                ForEach(appRules) { rule in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(rule.appName)
                                .font(.body)
                            Text(rule.bundleID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let profile = FanProfile.load(withID: rule.profileID) {
                            Label(profile.name, systemImage: profile.sfSymbol)
                                .font(.caption)
                        }
                    }
                }
                .onDelete(perform: deleteRule)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            appRules = loadAppRules()
        }
        .sheet(isPresented: $showAddRule) {
            NewAppRuleView { newRule in
                appRules.append(newRule)
                saveAppRules(appRules)
            }
        }
    }

    private func deleteRule(at offsets: IndexSet) {
        appRules.remove(atOffsets: offsets)
        saveAppRules(appRules)
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
        VStack(alignment: .leading, spacing: 20) {
            Text("About Chill")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text("A smart fan control app for Apple Silicon Macs")
                    .font(.body)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
