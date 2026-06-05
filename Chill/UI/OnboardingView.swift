import SwiftUI

/// First-run walkthrough, shown once after install. Introduces what Chill does,
/// the built-in profiles, and how to drive it from the menu bar. Adapts its copy
/// to the Mac it's running on (for example fanless MacBook Airs).
struct OnboardingView: View {
    @Environment(SensorManager.self) private var sensorManager
    @Environment(ProfileEngine.self) private var profileEngine
    var onFinish: () -> Void = {}

    @State private var step = 0
    private let lastStep = 3

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 40)
                .padding(.top, 44)
                .transition(.opacity)
                .id(step)

            footer
        }
        .frame(width: 560, height: 500)
        .background(backgroundLayer)
    }

    // MARK: - Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcomeStep
        case 1: whyStep
        case 2: profilesStep
        default: menuBarStep
        }
    }

    private var welcomeStep: some View {
        stepScaffold(symbol: "snowflake", title: "Welcome to Chill", subtitle: Brand.tagline) {
            Text("Chill keeps your Apple Silicon Mac cooler and quieter by taking smart control of its fans.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var whyStep: some View {
        stepScaffold(symbol: "thermometer.medium", title: "Why Chill?", subtitle: "macOS runs your fans late") {
            Text("Apple's thermal daemon lets the chip heat up before it spins the fans. Chill shifts the fan curve earlier, by a clear 4°C or 8°C, so temperatures and throttling stay in check.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var profilesStep: some View {
        stepScaffold(symbol: "slider.horizontal.3", title: "Pick a profile", subtitle: "Tap one to try it, switch any time from the menu bar") {
            VStack(spacing: 10) {
                ForEach(FanProfile.allBuiltIn, id: \.id) { profile in
                    profileRow(profile)
                }
            }
        }
    }

    private func profileRow(_ profile: FanProfile) -> some View {
        let isSelected = profileEngine.selectedProfile.id == profile.id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                profileEngine.switchProfile(profile)
            }
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Brand.primary.opacity(isSelected ? 0.28 : 0.16))
                        .frame(width: 36, height: 36)
                    Image(systemName: profile.sfSymbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Brand.primary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.name).fontWeight(.semibold)
                    Text(Self.descriptions[profile.name] ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Brand.primary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.10 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Brand.primary.opacity(isSelected ? 0.6 : 0), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var menuBarStep: some View {
        stepScaffold(symbol: "menubar.arrow.up.rectangle", title: "Up in your menu bar", subtitle: "Look for the thermometer") {
            VStack(spacing: 12) {
                Text("Click the thermometer icon near your clock to see live temperatures and fan speeds, and to switch profiles. Chill runs quietly in the background.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                if sensorManager.isFanless {
                    Label("This Mac is fanless, so Chill will simply monitor temperatures.", systemImage: "wind")
                        .font(.callout)
                        .foregroundStyle(Brand.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    // MARK: - Scaffolding

    @ViewBuilder
    private func stepScaffold<Detail: View>(
        symbol: String,
        title: String,
        subtitle: String,
        @ViewBuilder detail: () -> Detail
    ) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Brand.primary, Brand.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                    .frame(width: 78, height: 78)
                    .shadow(color: Brand.primary.opacity(0.4), radius: 12, y: 4)
                Image(systemName: symbol)
                    .font(.system(size: 33, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 5) {
                Text(title).font(Brand.titleFont)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            detail()
                .font(.system(.body, design: .rounded))
            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        VStack(spacing: 16) {
            HStack(spacing: 7) {
                ForEach(0...lastStep, id: \.self) { index in
                    Circle()
                        .fill(index == step ? Brand.primary : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            HStack {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.2)) { step -= 1 }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .opacity(step > 0 ? 1 : 0)
                .disabled(step == 0)

                Spacer()

                Button(step == lastStep ? "Get Started" : "Next") {
                    if step == lastStep {
                        onFinish()
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Brand.primary)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 26)
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [Brand.primary.opacity(0.12), Color(nsColor: .windowBackgroundColor)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private static let descriptions: [String: String] = [
        "Auto": "Hands off. Let macOS manage the fans.",
        "Chill 4°": "Apple's curve, shifted 4°C earlier.",
        "Chill 8°": "Cooler still, shifted 8°C earlier.",
        "Performance": "Aggressive ramp for sustained loads.",
    ]
}

#Preview {
    OnboardingView()
        .environment(SensorManager())
        .environment(ProfileEngine())
}
