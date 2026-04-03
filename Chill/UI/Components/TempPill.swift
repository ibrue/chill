import SwiftUI

struct TempPill: View {
    let icon: String
    let temp: Float
    let label: String

    private var color: Color {
        switch temp {
        case ..<50:
            return .cyan
        case 50..<70:
            return .orange
        default:
            return .red
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)

                Text(String(format: "%.0f°", temp))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(8)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.3), value: temp)
    }
}

#Preview {
    HStack(spacing: 8) {
        TempPill(icon: "keyboard", temp: 35, label: "Kbd")
        TempPill(icon: "cpu", temp: 65, label: "CPU")
        TempPill(icon: "gpu", temp: 58, label: "GPU")
        TempPill(icon: "battery.75", temp: 42, label: "Bat")
    }
    .padding()
}
