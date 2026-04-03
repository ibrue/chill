import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct NewAppRuleView: View {
    @State private var selectedApp: URL?
    @State private var selectedProfileID: UUID?
    @Environment(\.dismiss) var dismiss
    let onSave: (AppRule) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Form {
                Section("Select App") {
                    if let selectedApp {
                        HStack {
                            let icon = NSWorkspace.shared.icon(forFile: selectedApp.path)
                            Image(nsImage: icon)
                                .frame(width: 32, height: 32)

                            VStack(alignment: .leading) {
                                Text(selectedApp.lastPathComponent.replacingOccurrences(of: ".app", with: ""))
                                    .font(.body)
                                Text(selectedApp.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button(action: { self.selectedApp = nil }) {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Button(action: pickApp) {
                            Label("Choose App...", systemImage: "folder.badge.plus")
                        }
                    }
                }

                if selectedApp != nil {
                    Section("Profile") {
                        Picker("Apply Profile", selection: $selectedProfileID) {
                            Text("None").tag(nil as UUID?)

                            ForEach(FanProfile.allBuiltIn) { profile in
                                Text(profile.name).tag(profile.id as UUID?)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: save) {
                    Text("Add Rule")
                }
                .disabled(selectedApp == nil || selectedProfileID == nil)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            selectedApp = url
        }
    }

    private func save() {
        guard let app = selectedApp,
              let profileID = selectedProfileID
        else { return }

        let appName = app.lastPathComponent.replacingOccurrences(of: ".app", with: "")

        // Read bundle ID from the selected app's Info.plist
        let bundle = Bundle(url: app)
        let bundleID = bundle?.bundleIdentifier ?? appName

        let rule = AppRule(
            appName: appName,
            bundleID: bundleID,
            profileID: profileID
        )

        onSave(rule)
        dismiss()
    }
}

#Preview {
    NewAppRuleView { _ in }
}
