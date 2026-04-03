import SwiftUI

struct PopoverView: View {
    @Environment(SensorManager.self) var sensorManager
    @Environment(FanController.self) var fanController
    @Environment(ProfileEngine.self) var profileEngine
    @Environment(PowerMonitor.self) var powerMonitor

    @State private var showSettings = false

    var body: some View {
        ZStack {
            // Background with glass effect
            if #available(macOS 15, *) {
                Color.clear
                    .background(.ultraThinMaterial)
            } else {
                Color(nsColor: NSColor.controlBackgroundColor)
            }

            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "snowflake.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.cyan)

                    Text("Chill")
                        .font(.system(size: 18, weight: .semibold))

                    Spacer()

                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .help("Settings")

                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .help("Quit")
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                Divider()
                    .padding(.horizontal, 12)

                // Fan gauges
                HStack(spacing: 12) {
                    FanGauge(
                        fanIndex: 0,
                        rpm: Int(sensorManager.fan0RPM),
                        isManual: fanController.isManualMode
                    )

                    if sensorManager.fanCount > 1 {
                        FanGauge(
                            fanIndex: 1,
                            rpm: Int(sensorManager.fan1RPM),
                            isManual: fanController.isManualMode
                        )
                    }
                }
                .padding(.horizontal, 12)

                // Temperature pills
                HStack(spacing: 8) {
                    TempPill(
                        icon: "keyboard",
                        temp: sensorManager.keyboardTemp,
                        label: "Kbd"
                    )

                    TempPill(
                        icon: "cpu",
                        temp: sensorManager.cpuTemp,
                        label: "CPU"
                    )

                    TempPill(
                        icon: "cpu",
                        temp: sensorManager.gpuTemp,
                        label: "GPU"
                    )

                    TempPill(
                        icon: "battery.75",
                        temp: sensorManager.batteryTemp,
                        label: "Bat"
                    )
                }
                .padding(.horizontal, 12)

                // Profile switcher
                ProfileSwitcher(profileEngine: profileEngine)
                    .padding(.horizontal, 12)

                // Power bar
                PowerBar()
                    .padding(.horizontal, 12)

                Spacer()
            }
            .padding(.vertical, 8)
        }
        .frame(minWidth: 300, minHeight: 420)
        .sheet(isPresented: $showSettings) {
            SettingsView()
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
