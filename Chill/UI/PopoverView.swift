import SwiftUI

struct PopoverView: View {
    @Environment(SensorManager.self) var sensorManager
    @Environment(FanController.self) var fanController
    @Environment(ProfileEngine.self) var profileEngine
    @Environment(PowerMonitor.self) var powerMonitor

    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 16)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // MARK: - Status Row (Fan + Temps)
                    statusRow
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    // MARK: - Profile Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PROFILE")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)

                        ProfileSwitcher(profileEngine: profileEngine)
                            .padding(.horizontal, 16)
                    }

                    // MARK: - Active Profile Detail
                    if profileEngine.activeProfile.name != "Auto" {
                        activeProfileDetail
                            .padding(.horizontal, 16)
                    }

                    // MARK: - Power
                    PowerBar()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }
            }
        }
        .frame(width: 300)
        .frame(minHeight: 420, maxHeight: 520)
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

            // Connection status dot
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
            .help("Settings")

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit Chill")
        }
    }

    // MARK: - Status Row

    private var statusRow: some View {
        HStack(spacing: 10) {
            // Fan(s)
            fanStatus(index: 0, rpm: sensorManager.fan0RPM)

            if sensorManager.fanCount > 1 {
                fanStatus(index: 1, rpm: sensorManager.fan1RPM)
            }

            Spacer()

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

    private func fanStatus(index: Int, rpm: Float) -> some View {
        HStack(spacing: 8) {
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
                    .font(.system(size: 10))
                    .foregroundStyle(rpmColor(min(1.0, Double(rpm) / 8000.0)))
                    .rotationEffect(.degrees(rpm > 0 ? 360 : 0))
                    .animation(
                        rpm > 0
                            ? .linear(duration: max(0.3, 2.0 - Double(rpm) / 5000.0)).repeatForever(autoreverses: false)
                            : .default,
                        value: rpm > 0
                    )
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(Int(rpm))")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: Int(rpm))

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
                .frame(width: 28, alignment: .trailing)

            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(tempColor(value))

            Text(String(format: "%.0f\u{00B0}", value))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 32, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: Int(value))
        }
    }

    // MARK: - Active Profile Detail

    private var activeProfileDetail: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(profileEngine.activeProfile.description)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Sensor badge
            HStack(spacing: 4) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 9))
                Text("Watching: \(sensorDisplayName(profileEngine.activeProfile.primarySensor))")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.04))
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Helpers

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

    private func sensorDisplayName(_ key: String) -> String {
        switch key {
        case SMCKey.keyboardTemp: return "Keyboard"
        case SMCKey.cpuComplex: return "CPU"
        case SMCKey.gpuDie: return "GPU"
        case SMCKey.batteryTemp: return "Battery"
        default: return key
        }
    }
}

#Preview {
    PopoverView()
        .environment(SensorManager())
        .environment(FanController())
        .environment(ProfileEngine())
        .environment(PowerMonitor())
}
