import SwiftUI

struct PowerBar: View {
    @Environment(PowerMonitor.self) var powerMonitor

    var body: some View {
        HStack(spacing: 12) {
            // Power draw
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.yellow)

                Text(String(format: "%.0f W", powerMonitor.estimatedWatts))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.yellow.opacity(0.15))
            .cornerRadius(6)

            Spacer()

            // Battery status
            if !powerMonitor.isOnAC {
                HStack(spacing: 4) {
                    Image(systemName: batteryIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(batteryColor)

                    Text("\(powerMonitor.batteryPercent)%")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))

                    if powerMonitor.isCharging {
                        Text("Charging")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(batteryColor.opacity(0.15))
                .cornerRadius(6)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)

                    Text("AC Power")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15))
                .cornerRadius(6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var batteryIcon: String {
        let percent = powerMonitor.batteryPercent
        if percent > 75 { return "battery.100" }
        if percent > 50 { return "battery.75" }
        if percent > 25 { return "battery.50" }
        return "battery.25"
    }

    private var batteryColor: Color {
        let percent = powerMonitor.batteryPercent
        if percent > 30 { return .green }
        if percent > 15 { return .orange }
        return .red
    }
}

#Preview {
    VStack(spacing: 20) {
        PowerBar()
            .environment(PowerMonitor())
    }
    .padding()
}
