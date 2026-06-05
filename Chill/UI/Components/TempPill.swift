import SwiftUI

/// A small sensor pill: icon + temperature reading + label, wrapped in
/// `GlassCard` with a tier-tinted overlay layered on top of the glass.
struct TempPill: View {
    let icon: String
    let temp: Float
    let label: String

    private var tint: Color { Brand.tierColor(for: temp) }

    var body: some View {
        GlassCard(cornerRadius: 12, padding: 0) {
            ZStack {
                // Subtle tint overlay so glass + temperature semantics coexist.
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.18))

                VStack(spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(tint)
                        Text(temp > 0 ? String(format: "%.0f°", temp) : "-")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                    Text(label)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.3), value: temp)
    }
}

#Preview {
    HStack(spacing: 8) {
        TempPill(icon: "cpu",        temp: 65, label: "CPU")
        TempPill(icon: "memorychip", temp: 58, label: "GPU")
        TempPill(icon: "keyboard",   temp: 35, label: "Kbd")
        TempPill(icon: "battery.75", temp: 42, label: "Bat")
    }
    .padding()
    .frame(width: 320)
    .background(LinearGradient(colors: [.blue.opacity(0.4), .black], startPoint: .top, endPoint: .bottom))
}
