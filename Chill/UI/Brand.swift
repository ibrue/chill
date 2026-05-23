import SwiftUI

/// Centralized Chill brand tokens. Edit colors, fonts, and identity strings here
/// rather than scattering literals across views.
enum Brand {
    // MARK: - Identity

    static let name = "Chill"
    static let tagline = "Smart fan control for Apple Silicon"
    static let logoSymbol = "snowflake"
    static let menuBarSymbol = "thermometer.snowflake"

    // MARK: - Palette

    /// Primary ice blue — used for the wordmark, logo gradient start, and cool temps.
    static let primary = Color(red: 0.40, green: 0.78, blue: 0.95)

    /// Secondary mint — used as the logo gradient end and accent moments.
    static let secondary = Color(red: 0.62, green: 0.90, blue: 0.85)

    /// Warm temperatures (50–70°C range).
    static let warm = Color(red: 1.00, green: 0.72, blue: 0.30)

    /// Hot temperatures (>70°C).
    static let hot = Color(red: 0.98, green: 0.42, blue: 0.42)

    /// Logo / brand gradient.
    static var gradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Pick a temperature-pill color from a Celsius reading.
    static func tempColor(_ celsius: Float) -> Color {
        switch celsius {
        case ..<50: return primary
        case 50..<70: return warm
        default: return hot
        }
    }

    // MARK: - Typography

    static let titleFont = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let labelFont = Font.system(.callout, design: .rounded)
    static let captionFont = Font.system(size: 11, weight: .medium, design: .rounded)
}
