import AppKit

/// The app's icon, drawn in code so the repository holds no binary asset: a near-black squircle with a sun that is
/// also a dial. Eleven identical rays sweep 270° round the disk, mirror-symmetric about the vertical axis; the lit ones
/// are the brightness level.
/// `scripts/bundle.sh` runs the binary with `--render-icon <png> [pixels] [layer] [level]` to make `AppIcon.icns`,
/// and the site and README draw the same image.
@MainActor
enum AppIconRenderer {
    /// `.full` is the icon. `.tile` and `.glyph` are its two layers, so a banner can stack them and animate the rays.
    enum Layer: String {
        case full, tile, glyph
    }

    private static let rayCount = 11

    static func image(size: CGFloat, layer: Layer = .full, level: Double = 0.75) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            // The macOS icon grid: the tile is 80% of the canvas, centred, with corners of about 22.4% of its width.
            let tile = rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.1)
            if layer != .glyph { drawTile(tile) }
            if layer != .tile { drawDial(in: tile, level: level) }
            return true
        }
    }

    private static func drawTile(_ tile: NSRect) {
        let path = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.2237, yRadius: tile.width * 0.2237)
        NSGradient(colors: [NSColor(white: 0.21, alpha: 1), NSColor(white: 0.055, alpha: 1)])?.draw(in: path, angle: -90)

        // A faint sheen along the top edge, so the tile reads as a surface and not a flat shape.
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        let sheen = NSRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2)
        NSGradient(colors: [NSColor(white: 1, alpha: 0.07), NSColor(white: 1, alpha: 0)])?.draw(in: sheen, angle: -90)
        NSGraphicsContext.restoreGraphicsState()

        path.lineWidth = max(1, tile.width / 400)
        NSColor(white: 1, alpha: 0.09).setStroke()
        path.stroke()
    }

    private static func drawDial(in tile: NSRect, level: Double) {
        let unit = tile.width
        let centre = CGPoint(x: tile.midX, y: tile.midY)
        let lit = Int((level * Double(rayCount)).rounded())

        // Rays: from 7:30 clockwise to 4:30, all the same length and width, so the dial is symmetric left to right.
        for index in 0..<rayCount {
            let progress = Double(index) / Double(rayCount - 1)
            let angle = (225 - 270 * progress) * .pi / 180
            let inner = unit * 0.262
            let length = unit * 0.090
            let width = unit * 0.034
            let direction = CGPoint(x: cos(angle), y: sin(angle))
            let start = CGPoint(x: centre.x + direction.x * inner, y: centre.y + direction.y * inner)
            let end = CGPoint(x: centre.x + direction.x * (inner + length), y: centre.y + direction.y * (inner + length))
            let ray = NSBezierPath()
            ray.move(to: start)
            ray.line(to: end)
            ray.lineWidth = width
            ray.lineCapStyle = .round
            NSColor(white: 1, alpha: index < lit ? 1 : 0.20).setStroke()
            ray.stroke()
        }

        // The disk, with a soft glow: the sun the dial is turned up to.
        let radius = unit * 0.118
        let disk = NSBezierPath(ovalIn: NSRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = NSColor(white: 1, alpha: 0.35 + 0.25 * level)
        glow.shadowBlurRadius = unit * 0.05
        glow.shadowOffset = .zero
        glow.set()
        NSColor.white.setFill()
        disk.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(colors: [NSColor(white: 1, alpha: 1), NSColor(white: 0.84, alpha: 1)])?.draw(in: disk, angle: -90)
    }

    /// A square PNG of exactly `pixels` by `pixels`, independent of the display's scale.
    static func pngData(pixels: Int, layer: Layer = .full, level: Double = 0.75) -> Data? {
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let context = NSGraphicsContext(bitmapImageRep: representation) else { return nil }
        NSGraphicsContext.current = context
        image(size: CGFloat(pixels), layer: layer, level: level)
            .draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        return representation.representation(using: .png, properties: [:])
    }
}
