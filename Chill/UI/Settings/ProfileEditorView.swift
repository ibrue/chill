import SwiftUI
import Charts

struct ProfileEditorView: View {
    @State var profile: FanProfile
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            Section("Profile Info") {
                TextField("Name", text: $profile.name)

                Picker("Icon", selection: $profile.sfSymbol) {
                    ForEach([
                        ("leaf.fill", "Auto"),
                        ("keyboard.fill", "Keyboard"),
                        ("gauge", "Balanced"),
                        ("moon.fill", "Whisper"),
                        ("bolt.fill", "Performance"),
                    ], id: \.0) { value, label in
                        HStack {
                            Image(systemName: value)
                            Text(label)
                        }
                        .tag(value)
                    }
                }

                Picker("Primary Sensor", selection: $profile.primarySensor) {
                    ForEach(SMCKey.temperatureSensors, id: \.self) { key in
                        Text(SMCKey.displayName(for: key))
                            .tag(key)
                    }
                }
            }

            Section("Fan Curve") {
                Chart {
                    ForEach(profile.curve) { point in
                        PointMark(x: .value("Temp", point.tempCelsius), y: .value("RPM %", point.rpmPercent * 100))
                    }

                    LineMark(
                        x: .value("Temp", 0),
                        y: .value("RPM %", 0)
                    )
                    .foregroundStyle(.blue.opacity(0.3))
                }
                .frame(height: 200)

                VStack(spacing: 12) {
                    ForEach(profile.curve.sorted { $0.tempCelsius < $1.tempCelsius }) { point in
                        HStack {
                            Text("@ \(String(format: "%.0f", point.tempCelsius))°C")
                                .frame(width: 80)

                            Slider(
                                value: .init(
                                    get: { point.rpmPercent },
                                    set: { newValue in
                                        if let index = profile.curve.firstIndex(where: { $0.id == point.id }) {
                                            profile.curve[index].rpmPercent = newValue
                                        }
                                    }
                                ),
                                in: 0...1
                            )

                            Text(String(format: "%.0f%%", point.rpmPercent * 100))
                                .frame(width: 45, alignment: .trailing)

                            Button(action: {
                                profile.curve.removeAll { $0.id == point.id }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button(action: {
                        let newTemp = (profile.curve.map { $0.tempCelsius }.max() ?? 80) + 5
                        profile.curve.append(TempCurvePoint(temp: newTemp, rpmPercent: 0.5))
                    }) {
                        Label("Add Point", systemImage: "plus")
                    }
                }
            }

            Section("Hysteresis") {
                Slider(value: $profile.hysteresisDegrees, in: 1...10, step: 0.5)
                Text("\(String(format: "%.1f", profile.hysteresisDegrees)) seconds before RPM can decrease")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Edit Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    profile.save()
                    dismiss()
                }
            }
        }
    }
}

// MARK: - New Profile View

struct NewProfileView: View {
    @State private var name = "Custom Profile"
    @State private var icon = "fan.fill"
    @Environment(\.dismiss) var dismiss
    let onSave: (FanProfile) -> Void

    var body: some View {
        Form {
            Section("New Profile") {
                TextField("Name", text: $name)

                Picker("Icon", selection: $icon) {
                    ForEach([
                        ("fan.fill", "Fan"),
                        ("keyboard.fill", "Keyboard"),
                        ("gauge", "Gauge"),
                        ("moon.fill", "Moon"),
                        ("bolt.fill", "Bolt"),
                    ], id: \.0) { value, label in
                        HStack {
                            Image(systemName: value)
                            Text(label)
                        }
                        .tag(value)
                    }
                }
            }

            Button(action: {
                let profile = FanProfile(
                    name: name,
                    sfSymbol: icon,
                    curve: [
                        TempCurvePoint(temp: 40, rpmPercent: 0.3),
                        TempCurvePoint(temp: 70, rpmPercent: 0.7),
                        TempCurvePoint(temp: 90, rpmPercent: 1.0),
                    ]
                )
                onSave(profile)
                dismiss()
            }) {
                Text("Create")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileEditorView(profile: .balanced)
    }
}
