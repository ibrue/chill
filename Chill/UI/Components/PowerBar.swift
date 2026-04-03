import SwiftUI

struct PowerBar: View {
    @Environment(PowerMonitor.self) var powerMonitor

    var body: some View {
        HStack(spacing: 10) {
            // Power draw
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.yellow)

                Text(String(format: "%.0fW", powerMonitor.estimatedWatts))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Power source
            HStack(spacing: 4) {
                if powerMonitor.isOnAC {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)

                    Text("AC Power")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: batteryIcon)
                        .font(.system(size: 10))
                        .foregroundStyle(batteryColor)

                    Text("\(powerMonitor.batteryPercent)%")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.06))
        )
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
    PowerBar()
        .environment(PowerMonitor())
        .padding()
}
