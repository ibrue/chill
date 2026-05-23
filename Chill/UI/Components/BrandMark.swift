import SwiftUI

/// The Chill logo mark: a snowflake set inside a rounded gradient tile,
/// optionally paired with the wordmark.
struct BrandMark: View {
    enum Size {
        case small, medium, large

        var tile: CGFloat {
            switch self {
            case .small:  return 22
            case .medium: return 28
            case .large:  return 56
            }
        }

        var symbol: CGFloat {
            switch self {
            case .small:  return 13
            case .medium: return 17
            case .large:  return 34
            }
        }

        var corner: CGFloat { tile * 0.28 }
    }

    var size: Size = .medium
    var showsWordmark: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                    .fill(Brand.gradient)
                    .frame(width: size.tile, height: size.tile)
                    .shadow(color: Brand.primary.opacity(0.35), radius: 4, y: 2)

                Image(systemName: Brand.logoSymbol)
                    .font(.system(size: size.symbol, weight: .bold))
                    .foregroundStyle(.white)
            }

            if showsWordmark {
                Text(Brand.name)
                    .font(Brand.titleFont)
                    .foregroundStyle(.primary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        BrandMark(size: .small)
        BrandMark(size: .medium)
        BrandMark(size: .large)
        BrandMark(size: .medium, showsWordmark: false)
    }
    .padding()
}
