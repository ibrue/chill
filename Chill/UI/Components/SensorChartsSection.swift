import SwiftUI

struct SensorChartsSection: View {
    @Environment(SensorManager.self) var sensorManager
    @Environment(PowerMonitor.self) var powerMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACTIVITY")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)

            // Fan RPM sparkline
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "fan.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.cyan)

                    Text("Fan Speed")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(sensorManager.fan0RPM)) RPM")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                SensorSparkline(
                    data: sensorManager.fan0History,
                    color: .cyan,
                    unit: "RPM",
                    yDomain: 0...8000
                )
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.06))
            )

            // Power sparkline
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)

                    Text("Power")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(String(format: "%.0fW", powerMonitor.estimatedWatts))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                SensorSparkline(
                    data: powerMonitor.wattsHistory,
                    color: .yellow,
                    unit: "W",
                    yDomain: nil
                )
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.06))
            )
        }
    }
}

#Preview {
    SensorChartsSection()
        .environment(SensorManager())
        .environment(PowerMonitor())
        .padding()
        .frame(width: 300)
}
