import SwiftUI

struct FanGauge: View {
    let fanIndex: Int
    let rpm: Int
    let isManual: Bool

    private var maxRPM: Int { 8000 }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)

                // Arc background
                Circle()
                    .trim(from: 0.125, to: 0.875)  // 210° to 330° (270° sweep)
                    .stroke(Color.gray.opacity(0.1), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // RPM arc
                let progress = min(1.0, Double(rpm) / Double(maxRPM))
                Circle()
                    .trim(from: 0.125, to: 0.125 + (0.75 * progress))
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .cyan,
                                .blue,
                                progress > 0.5 ? .orange : .green,
                                progress > 0.85 ? .red : .orange
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: rpm)

                // Center text
                VStack(spacing: 4) {
                    Text("\(rpm)")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("RPM")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 120)

            // Label
            HStack {
                Text("Fan \(fanIndex)")
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                if isManual {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                } else {
                    Text("Auto")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        FanGauge(fanIndex: 0, rpm: 2000, isManual: false)
        FanGauge(fanIndex: 1, rpm: 5500, isManual: true)
    }
    .padding()
}
