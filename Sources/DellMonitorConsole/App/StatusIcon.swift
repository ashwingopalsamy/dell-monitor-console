import AppKit

/// The menu bar glyph: the app icon's dial, redrawn heavier so it reads at 18 pt. Eleven identical rays sweep 270°
/// round a centre dot, mirror-symmetric about the vertical axis, exactly as in the icon.
///
/// It says two things at a glance. The dot is there while an external monitor is detected, and absent when none is.
/// The lit rays are that monitor's brightness, never the built-in panel's; the rest stay faintly drawn, as in the icon.
///
/// The image is a template, so macOS tints it for the menu bar's light and dark appearances.
enum StatusIcon {
    private static let size: CGFloat = 18
    private static let rayCount = 11
    private static let diskRadius: CGFloat = 2.8
    private static let rayInner: CGFloat = 5.1
    private static let rayLength: CGFloat = 3.0
    private static let rayWidth: CGFloat = 1.6
    private static let unlit: CGFloat = 0.3
    private static let badgeDiameter: CGFloat = 5
    private static let badgeGap: CGFloat = 1.2

    /// `level` is 0...100 for the monitor shown, or nil when no external monitor is detected. `attention` adds a small dot in the
    /// top-right corner, cut out of the glyph, for a display that did not accept a change.
    static func image(level: Int?, attention: Bool) -> NSImage {
        let lit = level.map { min(rayCount, max(0, Int((Double($0) / 100 * Double(rayCount)).rounded()))) } ?? 0
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let centre = CGPoint(x: rect.midX, y: rect.midY)
            for index in 0..<rayCount {
                let progress = Double(index) / Double(rayCount - 1)
                let angle = (225 - 270 * progress) * .pi / 180
                let direction = CGPoint(x: cos(angle), y: sin(angle))
                let ray = NSBezierPath()
                ray.move(to: CGPoint(x: centre.x + direction.x * rayInner, y: centre.y + direction.y * rayInner))
                ray.line(to: CGPoint(x: centre.x + direction.x * (rayInner + rayLength),
                                     y: centre.y + direction.y * (rayInner + rayLength)))
                ray.lineWidth = rayWidth
                ray.lineCapStyle = .round
                NSColor.black.withAlphaComponent(index < lit ? 1 : unlit).setStroke()
                ray.stroke()
            }
            if level != nil {
                NSColor.black.setFill()
                NSBezierPath(ovalIn: NSRect(x: centre.x - diskRadius, y: centre.y - diskRadius,
                                            width: diskRadius * 2, height: diskRadius * 2)).fill()
            }
            if attention {
                let dot = NSRect(x: rect.maxX - badgeDiameter, y: rect.maxY - badgeDiameter,
                                 width: badgeDiameter, height: badgeDiameter)
                NSGraphicsContext.current?.compositingOperation = .clear
                NSBezierPath(ovalIn: dot.insetBy(dx: -badgeGap, dy: -badgeGap)).fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
                NSColor.black.setFill()
                NSBezierPath(ovalIn: dot).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
