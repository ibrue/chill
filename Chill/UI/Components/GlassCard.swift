import SwiftUI

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            if #available(macOS 15, *) {
                Color.clear
                    .background(.ultraThinMaterial)
            } else {
                VisualEffectView(material: .hudWindow)
            }

            content
        }
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Visual Effect View for older macOS

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

#Preview {
    GlassCard {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "thermometer.snowflake")
                Text("Glass Card Example")
                Spacer()
            }

            Text("This card uses glassmorphism on macOS 15+ or visual effect on older versions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    .padding()
}
