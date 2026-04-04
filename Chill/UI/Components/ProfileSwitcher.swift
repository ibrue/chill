import SwiftUI

struct ProfileSwitcher: View {
    @Bindable var profileEngine: ProfileEngine
    @Environment(PowerMonitor.self) var powerMonitor
    @State private var profiles = FanProfile.allBuiltIn + FanProfile.allCustom()

    var body: some View {
        VStack(spacing: 10) {
            ForEach(profiles) { profile in
                ProfileCard(
                    profile: profile,
                    isSelected: profileEngine.activeProfile.id == profile.id,
                    powerMode: profile.isAdaptive ? powerMonitor.currentPowerMode : nil,
                    action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            profileEngine.switchProfile(profile)
                        }
                    }
                )
            }
        }
        .onAppear {
            profiles = FanProfile.allBuiltIn + FanProfile.allCustom()
        }
    }
}

// MARK: - Profile Card

struct ProfileCard: View {
    let profile: FanProfile
    let isSelected: Bool
    var powerMode: PowerMode? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: profile.sfSymbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSelected ? accentColor : .secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? accentColor.opacity(0.15) : Color.clear)
                        )

                    // Name + subtitle
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)

                        if let powerMode, isSelected {
                            HStack(spacing: 4) {
                                Image(systemName: powerMode.sfSymbol)
                                    .font(.system(size: 9))
                                Text(powerMode.rawValue)
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(accentColor)
                        } else {
                            Text(profile.subtitle)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Mini curve (show active power mode curve for adaptive profiles)
                    MiniCurve(
                        curve: powerMode != nil ? profile.curve(for: powerMode!) : profile.curve,
                        accentColor: accentColor
                    )
                    .frame(width: 48, height: 24)
                    .opacity(isSelected ? 1.0 : 0.4)

                    // Selection indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(accentColor)
                    }
                }

                // Description shown when selected
                if isSelected && !profile.description.isEmpty {
                    Text(profile.description)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? accentColor.opacity(0.08) : Color.gray.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var accentColor: Color {
        switch profile.name {
        case "Auto": return .green
        case "Adaptive": return .teal
        case "Balanced": return .blue
        case "Whisper": return .purple
        case "Performance": return .orange
        default: return .blue
        }
    }
}

// MARK: - Mini Curve Visualization

struct MiniCurve: View {
    let curve: [TempCurvePoint]
    let accentColor: Color

    var body: some View {
        Canvas { context, size in
            let sorted = curve.sorted { $0.tempCelsius < $1.tempCelsius }
            guard sorted.count >= 2 else { return }

            let minTemp = sorted.first!.tempCelsius
            let maxTemp = sorted.last!.tempCelsius
            let tempRange = maxTemp - minTemp

            guard tempRange > 0 else { return }

            var path = Path()
            for (i, point) in sorted.enumerated() {
                let x = CGFloat((point.tempCelsius - minTemp) / tempRange) * size.width
                let y = size.height - CGFloat(point.rpmPercent) * size.height
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(path, with: .color(accentColor), lineWidth: 1.5)

            // Fill under curve
            var fillPath = path
            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()
            context.fill(fillPath, with: .color(accentColor.opacity(0.15)))
        }
    }
}

#Preview {
    ProfileSwitcher(profileEngine: ProfileEngine())
        .environment(PowerMonitor())
        .padding()
        .frame(width: 300)
}
