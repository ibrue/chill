import SwiftUI

struct ProfileSwitcher: View {
    @Bindable var profileEngine: ProfileEngine
    @State private var profiles = FanProfile.allBuiltIn

    var body: some View {
        VStack(spacing: 8) {
            Text("Profile")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(profiles) { profile in
                        ProfilePill(
                            profile: profile,
                            isSelected: profileEngine.activeProfile.id == profile.id,
                            action: {
                                profileEngine.switchProfile(profile)
                            }
                        )
                    }
                }
            }
        }
    }
}

struct ProfilePill: View {
    let profile: FanProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: profile.sfSymbol)
                    .font(.system(size: 12, weight: .semibold))

                Text(profile.name)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    ProfileSwitcher(profileEngine: ProfileEngine())
        .padding()
}
