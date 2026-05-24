import SwiftUI

struct BrandMark: View {
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Brand.primary, Brand.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: Brand.logoSymbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)
            .shadow(color: Brand.primary.opacity(0.28), radius: 6, y: 2)

            Text(Brand.name)
                .font(Brand.titleFont)
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Brand.name)
    }
}

#Preview {
    BrandMark()
        .padding()
}
