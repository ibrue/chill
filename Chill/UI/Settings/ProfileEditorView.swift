import SwiftUI

struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: FanProfile
    private let original: FanProfile
    private let isReadOnly: Bool
    private let onSave: ((FanProfile) -> Void)?

    init(profile: FanProfile, isReadOnly: Bool = false, onSave: ((FanProfile) -> Void)? = nil) {
        self._draft = State(initialValue: profile)
        self.original = profile
        self.isReadOnly = isReadOnly
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            editorBackground

            VStack(alignment: .leading, spacing: 16) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        profileInfoCard
                        curveCard
                        hysteresisCard
                    }
                    .padding(.bottom, 4)
                }
                footer
            }
            .padding(18)
        }
        .frame(minWidth: 620, minHeight: 640)
    }

    private var editorBackground: some View {
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
        HStack(spacing: 12) {
            Image(systemName: draft.sfSymbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Brand.primary)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Brand.primary.opacity(0.16)))

            VStack(alignment: .leading, spacing: 3) {
                Text(isReadOnly ? "Profile Preview" : (original.id == draft.id && !original.isBuiltIn ? "Edit Profile" : "New Profile"))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text(isReadOnly ? "Built-ins can be duplicated, but not changed." : "Tune the fan curve Chill applies for this profile.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var profileInfoCard: some View {
        GlassCard(cornerRadius: 16, padding: 14) {
            VStack(alignment: .leading, spacing: 14) {
                SettingsEditorTitle(icon: "person.crop.square", title: "Profile")

                TextField("Profile name", text: $draft.name)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isReadOnly)

                HStack(spacing: 12) {
                    Picker("Icon", selection: $draft.sfSymbol) {
                        ForEach(iconOptions, id: \.0) { value, label in
                            Label(label, systemImage: value).tag(value)
                        }
                    }
                    .disabled(isReadOnly)

                    Picker("Sensor", selection: $draft.primarySensor) {
                        ForEach(SMCKey.primaryTemperatureKeys, id: \.self) { key in
                            Text(SMCKey.displayName(for: key)).tag(key)
                        }
                    }
                    .disabled(isReadOnly)
                }
            }
        }
    }

    private var curveCard: some View {
        GlassCard(cornerRadius: 16, padding: 14) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SettingsEditorTitle(icon: "chart.xyaxis.line", title: "Fan Curve")
                    Spacer()
                    if !isReadOnly {
                        Button(action: addPoint) {
                            Label("Add Point", systemImage: "plus")
                        }
                    }
                }

                FanCurveChart(curve: draft.curve, currentTemp: 0)
                    .frame(height: 160)

                VStack(spacing: 10) {
                    ForEach(sortedCurve) { point in
                        curvePointRow(point)
                    }
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(Brand.hot)
                }
            }
        }
    }

    private var hysteresisCard: some View {
        GlassCard(cornerRadius: 16, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                SettingsEditorTitle(icon: "timer", title: "Fan Smoothing")

                HStack {
                    Slider(value: $draft.hysteresisDegrees, in: 1...10, step: 0.5)
                        .disabled(isReadOnly)
                    Text("\(String(format: "%.1f", draft.hysteresisDegrees))s")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }

                Text("Chill waits this long before allowing fan speed to decrease, which avoids rapid RPM changes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)

            if !isReadOnly {
                Button("Restore Defaults") {
                    draft = original
                }
                .disabled(draft == original)
            }

            Spacer()

            if isReadOnly {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Save") {
                    var saved = draft
                    saved.name = saved.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    saved.curve = sortedCurve
                    saved.isBuiltIn = false
                    onSave?(saved)
                    dismiss()
                }
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var sortedCurve: [TempCurvePoint] {
        draft.curve.sorted { $0.tempCelsius < $1.tempCelsius }
    }

    private var isValid: Bool {
        validationMessage == nil
    }

    private var validationMessage: String? {
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Name is required."
        }
        if draft.curve.count < 2 {
            return "Add at least two curve points."
        }
        let temps = draft.curve.map { Int($0.tempCelsius.rounded()) }
        if Set(temps).count != temps.count {
            return "Curve point temperatures must be unique."
        }
        return nil
    }

    private let iconOptions = [
        ("fan.fill", "Fan"),
        ("leaf.fill", "Auto"),
        ("snowflake", "Chill"),
        ("snowflake.fill", "Deep Chill"),
        ("bolt.fill", "Performance"),
        ("gauge.with.dots.needle.67percent", "Gauge"),
    ]

    @ViewBuilder
    private func curvePointRow(_ point: TempCurvePoint) -> some View {
        HStack(spacing: 10) {
            Stepper(
                value: binding(for: point, keyPath: \.tempCelsius),
                in: 25...105,
                step: 1
            ) {
                Text("\(Int(point.tempCelsius.rounded()))°C")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(width: 54, alignment: .leading)
            }
            .disabled(isReadOnly)
            .frame(width: 150)

            Slider(value: binding(for: point, keyPath: \.rpmPercent), in: 0.15...1, step: 0.05)
                .disabled(isReadOnly)

            Text("\(Int((point.rpmPercent * 100).rounded()))%")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 42, alignment: .trailing)

            if !isReadOnly {
                Button(role: .destructive) {
                    draft.curve.removeAll { $0.id == point.id }
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(draft.curve.count <= 2)
            }
        }
    }

    private func binding(for point: TempCurvePoint, keyPath: WritableKeyPath<TempCurvePoint, Float>) -> Binding<Double> {
        Binding<Double>(
            get: {
                Double(draft.curve.first(where: { $0.id == point.id })?[keyPath: keyPath] ?? point[keyPath: keyPath])
            },
            set: { newValue in
                guard let index = draft.curve.firstIndex(where: { $0.id == point.id }) else { return }
                draft.curve[index][keyPath: keyPath] = Float(newValue)
            }
        )
    }

    private func addPoint() {
        let nextTemp = min((draft.curve.map(\.tempCelsius).max() ?? 80) + 5, 105)
        draft.curve.append(TempCurvePoint(temp: nextTemp, rpmPercent: 0.55))
    }
}

private struct SettingsEditorTitle: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
    }
}

struct NewProfileView: View {
    let onSave: (FanProfile) -> Void

    var body: some View {
        ProfileEditorView(profile: FanProfile(
            name: "Custom Profile",
            sfSymbol: "fan.fill",
            curve: [
                TempCurvePoint(temp: 40, rpmPercent: 0.30),
                TempCurvePoint(temp: 70, rpmPercent: 0.70),
                TempCurvePoint(temp: 90, rpmPercent: 1.00),
            ]
        ), onSave: onSave)
    }
}

#Preview {
    ProfileEditorView(profile: .chill4, isReadOnly: true)
}
