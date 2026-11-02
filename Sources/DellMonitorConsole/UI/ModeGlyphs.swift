import SwiftUI

// The Display panel's three glyphs. Control Center draws its own artwork here, not SF Symbols, so these are vector
// copies measured from a 2x screenshot of the panel. Geometry is in points on an 18pt box centred in the frame and
// scales with it. Each glyph is one path: a fill or a fade covers it evenly, and its holes show what is behind.

/// A mode's glyph, filled with the foreground style.
struct ModeGlyph: View {
    let id: ModeID

    var body: some View {
        switch id {
        case .darkMode: DarkModeGlyph()
        case .nightShift: NightShiftGlyph()
        case .trueTone: TrueToneGlyph()
        }
    }
}

/// A disc split down the middle: solid on the left, a ring on the right, and a small disc at the centre drawn the
/// other way round.
struct DarkModeGlyph: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        let box = GlyphBox(rect)
        let outer = box.disc(DarkModeArt.radius)
        let dot = box.disc(DarkModeArt.dot)
        let solid = outer.intersection(box.half(.left)).subtracting(dot)
        let ring = outer.subtracting(box.disc(DarkModeArt.radius - DarkModeArt.ring)).intersection(box.half(.right))
        return solid.union(ring).union(dot.intersection(box.half(.right)))
    }
}

/// A sun whose centre is a ring. Inside it a disc set up and to the right leaves a crescent moon of background.
struct NightShiftGlyph: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        let box = GlyphBox(rect)
        let ring = box.disc(SunArt.core).subtracting(box.disc(SunArt.core - NightShiftArt.ring))
        var path = ring.union(box.disc(NightShiftArt.moonRadius, at: NightShiftArt.moonCentre))
        path.addPath(box.rays())
        return path
    }
}

/// A sun whose centre disc is cut into bars by horizontal gaps that narrow toward the bottom.
struct TrueToneGlyph: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        let box = GlyphBox(rect)
        var cuts = Path()
        for gap in TrueToneArt.gaps { cuts.addRect(box.band(gap)) }
        var path = box.disc(SunArt.core).subtracting(cuts)
        path.addPath(box.rays())
        return path
    }
}

private enum DarkModeArt {
    /// 17.1pt across.
    static let radius: CGFloat = 8.55
    static let ring: CGFloat = 1.65
    /// 6.6pt across.
    static let dot: CGFloat = 3.3
}

/// What the Night Shift and True Tone suns share.
private enum SunArt {
    /// The centre ring or disc: 8.65pt across.
    static let core: CGFloat = 4.325
    /// How far the rays reach from the centre, round caps included, and how thick they are.
    static let rayInner: CGFloat = 5.85
    static let rayOuter: CGFloat = 9.2
    static let rayWidth: CGFloat = 1.65
}

private enum NightShiftArt {
    static let ring: CGFloat = 1.55
    /// The disc inside the ring. It reaches into the ring, so only a crescent of background is left.
    static let moonCentre = CGPoint(x: 1.3, y: -1.25)
    static let moonRadius: CGFloat = 2.3
}

private enum TrueToneArt {
    /// Each gap's top and bottom, measured down from the centre: 1.33, 1.0, 0.55 and 0.39pt tall.
    static let gaps: [ClosedRange<CGFloat>] = [-3.885 ... -2.555, -1.94 ... -0.94, 0.115 ... 0.67, 2.17 ... 2.56]
}

/// The 18pt design box mapped onto a rect: offsets in points from its centre, scaled to fit.
private struct GlyphBox {
    enum Side { case left, right }

    static let side: CGFloat = 18
    let centre: CGPoint
    let scale: CGFloat

    init(_ rect: CGRect) {
        centre = CGPoint(x: rect.midX, y: rect.midY)
        scale = min(rect.width, rect.height) / Self.side
    }

    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: centre.x + x * scale, y: centre.y + y * scale)
    }

    func disc(_ radius: CGFloat, at offset: CGPoint = .zero) -> Path {
        let r = radius * scale
        let c = point(offset.x, offset.y)
        return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    /// Everything to one side of the vertical centre line, out past the box.
    func half(_ side: Side) -> Path {
        let reach = Self.side * scale
        let x = side == .left ? centre.x - reach : centre.x
        return Path(CGRect(x: x, y: centre.y - reach, width: reach, height: 2 * reach))
    }

    /// A horizontal band across the box, `span` measured down from the centre.
    func band(_ span: ClosedRange<CGFloat>) -> CGRect {
        let reach = Self.side * scale
        return CGRect(x: centre.x - reach, y: centre.y + span.lowerBound * scale,
                      width: 2 * reach, height: (span.upperBound - span.lowerBound) * scale)
    }

    /// Eight round-capped rays, four on the axes and four on the diagonals.
    func rays() -> Path {
        let from = SunArt.rayInner + SunArt.rayWidth / 2
        let to = SunArt.rayOuter - SunArt.rayWidth / 2
        var spokes = Path()
        for step in 0..<8 {
            let angle = CGFloat(step) * .pi / 4
            let (dx, dy) = (cos(angle), sin(angle))
            spokes.move(to: point(from * dx, from * dy))
            spokes.addLine(to: point(to * dx, to * dy))
        }
        return spokes.strokedPath(StrokeStyle(lineWidth: SunArt.rayWidth * scale, lineCap: .round))
    }
}
