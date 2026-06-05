import SwiftUI

/// Compact horizontal "Fan N · 2400 RPM" cell. Used in the bottom row of the
/// popover now that FanCurveChart carries the visual weight.
struct FanReadout: View {
    let fanIndex: Int
    let rpm: Int
    let isManual: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "fan")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isManual ? Brand.warm : Brand.primary)

            VStack(alignment: .leading, spacing: 1) {
                Text("Fan \(fanIndex)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(rpm > 0 ? "\(rpm)" : "-")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(rpm)))
            }

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    HStack {
        FanReadout(fanIndex: 0, rpm: 2400, isManual: false)
        FanReadout(fanIndex: 1, rpm: 2200, isManual: true)
    }
    .padding()
    .frame(width: 280)
    .background(.black)
}
