import SwiftUI

/// Power + battery readout intended to live inside a GlassCard.
/// Wattage comes from `SensorManager.systemWatts` (SMC PSTR); shows "-" when
/// the key isn't supported on this Mac. Battery state still comes from
/// IOPowerSources via `PowerMonitor`.
struct PowerBar: View {
    @Environment(PowerMonitor.self) var powerMonitor
    @Environment(SensorManager.self) var sensorManager

    var body: some View {
        HStack(spacing: 10) {
            wattChip
            Spacer(minLength: 4)
            batteryChip
        }
    }

    private var wattChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Brand.warm)
            Text(wattText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(sensorManager.systemWatts)))
            Text("W")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var wattText: String {
        let w = sensorManager.systemWatts
        return w > 0 ? String(format: "%.0f", w) : "-"
    }

    @ViewBuilder
    private var batteryChip: some View {
        if powerMonitor.isOnAC {
            HStack(spacing: 4) {
                Image(systemName: "powerplug.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Brand.calm)
                Text("AC")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                if powerMonitor.isCharging {
                    Text("· charging")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: batteryIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(batteryColor)
                Text("\(powerMonitor.batteryPercent)%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }

    private var batteryIcon: String {
        let p = powerMonitor.batteryPercent
        if p > 75 { return "battery.100" }
        if p > 50 { return "battery.75" }
        if p > 25 { return "battery.50" }
        return "battery.25"
    }

    private var batteryColor: Color {
        let p = powerMonitor.batteryPercent
        if p > 30 { return Brand.calm }
        if p > 15 { return Brand.warm }
        return Brand.hot
    }
}

#Preview {
    PowerBar()
        .environment(PowerMonitor())
        .environment(SensorManager())
        .padding()
        .frame(width: 280)
        .background(.black)
}
