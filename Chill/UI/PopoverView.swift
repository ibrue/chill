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
        VStack(spacing: 8) {
            // Row 1: Fans
            HStack(spacing: 0) {
                fanPill(label: "Fan 1", rpm: sensorManager.fan0RPM)

                if sensorManager.fanCount > 1 {
                    Spacer(minLength: 8)
                    fanPill(label: "Fan 2", rpm: sensorManager.fan1RPM)
                }
            }

            // Row 2: Temps
            HStack(spacing: 8) {
                tempPill(icon: "cpu", value: sensorManager.cpuTemp, label: "CPU")
                tempPill(icon: "keyboard", value: sensorManager.keyboardTemp, label: "Keys")
                tempPill(icon: "memorychip", value: sensorManager.gpuTemp, label: "GPU")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.06))
        )
    }

    private func fanPill(label: String, rpm: Float) -> some View {
        VStack(spacing: 2) {
            Text(formatRPM(rpm))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)

            HStack(spacing: 3) {
                Image(systemName: "fan.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.cyan)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tempPill(icon: String, value: Float, label: String) -> some View {
        VStack(spacing: 3) {
            Text(String(format: "%.0f\u{00B0}", value))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)

            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundStyle(tempColor(value))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(tempColor(value).opacity(0.08))
        )
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
