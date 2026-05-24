import SwiftUI

enum Brand {
    static let name = "Chill"
    static let tagline = "Smart fan control for Apple Silicon"

    static let primary = Color(red: 0.40, green: 0.78, blue: 0.95)
    static let secondary = Color(red: 0.62, green: 0.90, blue: 0.85)
    static let warm = Color(red: 1.00, green: 0.72, blue: 0.30)
    static let hot = Color(red: 0.98, green: 0.42, blue: 0.42)
    static let calm = Color(red: 0.47, green: 0.82, blue: 0.54)

    static let logoSymbol = "snowflake"
    static let titleFont = Font.system(.title2, design: .rounded).weight(.semibold)
    static let labelFont = Font.system(.callout, design: .rounded)

    /// Map a temperature in °C to a tier color (cool→warm→hot).
    static func tierColor(for temp: Float) -> Color {
        switch temp {
        case ..<50:   return primary
        case 50..<70: return warm
        default:      return hot
        }
    }
}
