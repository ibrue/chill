import SwiftUI

struct PopoverView: View {
    @Environment(ChillSettingsStore.self) var settingsStore
    @Environment(SensorManager.self) var sensorManager
    @Environment(FanController.self) var fanController
    @Environment(ProfileEngine.self) var profileEngine
    @Environment(PowerMonitor.self) var powerMonitor

    var onOpenSettings: () -> Void = {}

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 12) {
                header
                curveCard
                ProfileSwitcher(profileEngine: profileEngine, profiles: settingsStore.allProfiles)
                sensorRow
                bottomRow
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .frame(minWidth: 320, minHeight: 480)
    }

    // MARK: - Pieces

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [Brand.primary.opacity(0.12), .black.opacity(0.001)],
                startPoint: .top,
                endPoint: .bottom
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
        HStack(spacing: 8) {
            BrandMark()
            Spacer()
            iconButton("gear", help: "Settings", action: onOpenSettings)
            iconButton("xmark", help: "Quit") { NSApplication.shared.terminate(nil) }
        }
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var curveCard: some View {
        GlassCard(cornerRadius: 16, padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: profileEngine.activeProfile.sfSymbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Brand.primary)
                    Text(profileEngine.activeProfile.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Spacer()
                    nowChip
                }

                FanCurveChart(
                    curve: profileEngine.activeProfile.curve,
                    currentTemp: sensorManager.cpuTemp
                )
            }
        }
    }

    private var nowChip: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Brand.tierColor(for: sensorManager.cpuTemp))
                .frame(width: 6, height: 6)
            Text(sensorManager.cpuTemp > 0
                 ? String(format: "%.0f°C", sensorManager.cpuTemp)
                 : "—")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(.white.opacity(0.08)))
    }

    private var sensorRow: some View {
        HStack(spacing: 8) {
            TempPill(icon: "cpu",        temp: sensorManager.cpuTemp,      label: "CPU")
            TempPill(icon: "memorychip", temp: sensorManager.gpuTemp,      label: "GPU")
            TempPill(icon: "keyboard",   temp: sensorManager.keyboardTemp, label: "Kbd")
            TempPill(icon: "battery.75", temp: sensorManager.batteryTemp,  label: "Bat")
        }
    }

    private var bottomRow: some View {
        GlassCard(cornerRadius: 14, padding: 12) {
            VStack(spacing: 10) {
                HStack(spacing: 14) {
                    FanReadout(
                        fanIndex: 0,
                        rpm: Int(sensorManager.fan0RPM),
                        isManual: fanController.isManualMode
                    )
                    if sensorManager.fanCount > 1 {
                        FanReadout(
                            fanIndex: 1,
                            rpm: Int(sensorManager.fan1RPM),
                            isManual: fanController.isManualMode
                        )
                    }
                }
                Divider().opacity(0.3)
                PowerBar()
            }
        }
    }
}

#Preview {
    PopoverView()
        .environment(ChillSettingsStore())
        .environment(SensorManager())
        .environment(FanController())
        .environment(ProfileEngine())
        .environment(PowerMonitor())
        .frame(width: 320, height: 480)
}
