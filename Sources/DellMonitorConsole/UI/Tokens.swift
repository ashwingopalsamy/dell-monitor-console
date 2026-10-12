import SwiftUI
import AppKit

// The same tokens as atomberg-console, trimmed to what this app draws. Colour is scarce: the only hue is the
// orange attention glyph. Everything else is label colours and neutral fills.

enum Palette {
    static let attention = Color(nsColor: .systemOrange)

    static let label = Color(nsColor: .labelColor)
    static let secondary = Color(nsColor: .secondaryLabelColor)
    static let tertiary = Color(nsColor: .tertiaryLabelColor)
    static let separator = Color(nsColor: .separatorColor)
    static let wellFill = Color(nsColor: .systemFill)
    static let trackFill = Color(nsColor: .secondarySystemFill)
    static let groupFill = Color(nsColor: .tertiarySystemFill)
    static let hover = Color.primary.opacity(0.06)
    static let hoverStrong = Color.primary.opacity(0.12)
}

enum Metric {
    static let popoverWidth: CGFloat = 320
    static let popoverRadius: CGFloat = 20
    /// Clear ring around the surface, for its shadow.
    static let panelMargin: CGFloat = 32
    static let groupInset: CGFloat = 8
    static let groupRadius: CGFloat = 12
    static let cardPadding: CGFloat = 4
    static let side: CGFloat = 16
    static let content: CGFloat = 288
    static let header: CGFloat = 40
    static let well: CGFloat = 24
    static let hitTarget: CGFloat = 28
    static let hoverRadius: CGFloat = 10
    static let hoverInset: CGFloat = 10
    static let nameRow: CGFloat = 36
}

enum Motion {
    static let hover = Animation.easeOut(duration: 0.12)
    static let numeric = Animation.snappy(duration: 0.25)
    static let push = Animation.easeInOut(duration: 0.24)
    static let reduced = Animation.easeOut(duration: 0.12)

    static func pick(_ animation: Animation, _ reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : animation
    }
}
