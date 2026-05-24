import SwiftUI

/// A rounded card backed by Liquid Glass on macOS 26, .ultraThinMaterial on 15,
/// and NSVisualEffectView .hudWindow on 14.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 14
    var padding: CGFloat = 12
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Group {
            if #available(macOS 26, *) {
                content
                    .padding(padding)
                    .glassEffect(.regular, in: shape)
            } else if #available(macOS 15, *) {
                content
                    .padding(padding)
                    .background(.ultraThinMaterial, in: shape)
                    .overlay(shape.strokeBorder(.white.opacity(0.18), lineWidth: 1))
            } else {
                content
                    .padding(padding)
                    .background(
                        VisualEffectView(material: .hudWindow)
                            .clipShape(shape)
                    )
                    .overlay(shape.strokeBorder(.white.opacity(0.18), lineWidth: 1))
            }
        }
    }
}

// MARK: - Visual Effect View fallback for macOS 14

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

#Preview {
    GlassCard {
        VStack(alignment: .leading, spacing: 6) {
            Text("Glass Card").font(.system(.headline, design: .rounded))
            Text("Liquid Glass on macOS 26, materials on older.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    .padding()
    .frame(width: 280)
    .background(LinearGradient(colors: [.blue.opacity(0.4), .purple.opacity(0.3)], startPoint: .top, endPoint: .bottom))
}
