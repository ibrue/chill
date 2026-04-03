import SwiftUI

struct PopoverView: View {
    @Environment(SensorManager.self) var sensorManager
    @Environment(FanController.self) var fanController
    @Environment(ProfileEngine.self) var profileEngine
    @Environment(PowerMonitor.self) var powerMonitor

    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 16)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Status Row (Fan + Temps)
                    statusRow
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    // Activity Charts
                    SensorChartsSection()
                        .padding(.horizontal, 16)

                    // Profile Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PROFILE")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)

                        ProfileSwitcher(profileEngine: profileEngine)
                            .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 14)
                }
            }
        }
        .frame(width: 300)
        .frame(minHeight: 420, maxHeight: 600)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "snowflake")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.cyan)

            Text("Chill")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Spacer()

            Circle()
                .fill(fanController.isHelperConnected ? Color.green : Color.red.opacity(0.6))
                .frame(width: 6, height: 6)
                .help(fanController.isHelperConnected ? "Helper connected" : "Helper not running")

            Button(action: { showSettings = true }) {
                Image(systemName: "gear")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Status Row

    private var statusRow: some View {
        HStack(spacing: 0) {
            // Fan(s)
            HStack(spacing: 12) {
                fanStatus(rpm: sensorManager.fan0RPM)

                if sensorManager.fanCount > 1 {
                    fanStatus(rpm: sensorManager.fan1RPM)
                }
            }

            Spacer(minLength: 12)

            // Temps
            VStack(alignment: .trailing, spacing: 6) {
                tempLabel(icon: "cpu", value: sensorManager.cpuTemp, label: "CPU")
                tempLabel(icon: "keyboard", value: sensorManager.keyboardTemp, label: "Keys")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.06))
        )
    }

    private func fanStatus(rpm: Float) -> some View {
        HStack(spacing: 6) {
            // Mini arc gauge
            ZStack {
                Circle()
                    .trim(from: 0.2, to: 0.8)
                    .stroke(Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(90))

                let progress = min(1.0, Double(rpm) / 8000.0)
                Circle()
                    .trim(from: 0.2, to: 0.2 + (0.6 * progress))
                    .stroke(
                        rpmColor(progress),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: rpm)

                Image(systemName: "fan.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(rpmColor(min(1.0, Double(rpm) / 8000.0)))
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(formatRPM(rpm))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize()

                Text("RPM")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func tempLabel(icon: String, value: Float, label: String) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(tempColor(value))

            Text(String(format: "%.0f\u{00B0}", value))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(minWidth: 28, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private func formatRPM(_ rpm: Float) -> String {
        let intRPM = Int(rpm)
        if intRPM >= 1000 {
            return String(format: "%d,%03d", intRPM / 1000, intRPM % 1000)
        }
        return "\(intRPM)"
    }

    private func rpmColor(_ progress: Double) -> Color {
        if progress < 0.3 { return .cyan }
        if progress < 0.6 { return .blue }
        if progress < 0.8 { return .orange }
        return .red
    }

    private func tempColor(_ temp: Float) -> Color {
        if temp < 45 { return .cyan }
        if temp < 65 { return .blue }
        if temp < 80 { return .orange }
        return .red
    }
}

#Preview {
    PopoverView()
        .environment(SensorManager())
        .environment(FanController())
        .environment(ProfileEngine())
        .environment(PowerMonitor())
}
