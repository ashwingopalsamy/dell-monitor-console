import SwiftUI
import AppKit

/// The menu bar popover body: Liquid Glass, 320pt wide, squircle radius 20. The app hosts it in a clear panel, so
/// it draws no window background of its own. The content is pinned to the top, so the panel never has to resize.
struct GlassPopover<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            // The panel is key only so its glass draws active. It has no text fields, so a focus ring is only noise.
            .focusEffectDisabled()
            .frame(width: Metric.popoverWidth)
            .clipShape(.rect(cornerRadius: Metric.popoverRadius, style: .continuous))
            .glassEffect(.regular, in: .rect(cornerRadius: Metric.popoverRadius, style: .continuous))
            .background { SurfaceShadow() }
            // The window is wider than the surface by this ring on both sides, so the shadow has room.
            .padding(.horizontal, Metric.panelMargin)
            .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// Only the part outside the surface is drawn: the glass is translucent and must not be darkened from behind.
private struct SurfaceShadow: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metric.popoverRadius, style: .continuous)
        shape
            .fill(Color.black)
            .shadow(color: .black.opacity(0.30), radius: 16, x: 0, y: 6)
            .mask {
                Rectangle()
                    .padding(-Metric.panelMargin)
                    .overlay { shape.blendMode(.destinationOut) }
                    .compositingGroup()
            }
    }
}

/// A subtle group: a faint squircle behind content, inset so its radius is concentric with the popover.
struct Card<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.vertical, Metric.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            CardBackground().padding(.horizontal, Metric.groupInset)
        }
    }
}

struct CardBackground: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metric.groupRadius, style: .continuous)
        shape.fill(Palette.groupFill)
            .overlay {
                if contrast == .increased { shape.strokeBorder(Palette.separator, lineWidth: 1) }
            }
    }
}

struct Hairline: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle().fill(Palette.separator).frame(height: 1 / displayScale)
    }
}

/// A 28pt Liquid Glass circle round a symbol, the material of the header buttons. No hue, ever. The glass is a modifier
/// on the glyph, so it draws behind it and no fade or group sits above it. Decorative: the row it sits in names the
/// display.
struct Well<Glyph: View>: View {
    @ViewBuilder var glyph: Glyph

    var body: some View {
        glyph
            .frame(width: Metric.well, height: Metric.well)
            .glassEffect(.regular, in: .circle)
            .accessibilityHidden(true)
    }
}

/// The system slider's look: a fill in the accent colour, a white capsule knob and a sun at each end, as in Control
/// Center. A real backlight uses the accent; a software dim is drawn in neutral grey, so the two cannot be mistaken.
struct BrightnessSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var backlight: Bool
    var label: String

    private static let knobWidth: CGFloat = 26
    private static let knobHeight: CGFloat = 18
    private static let trackHeight: CGFloat = 8
    /// The knob grows by this while held, about its own centre, so the layout and the value's position do not move.
    private static let heldScale: CGFloat = 1.25
    /// VoiceOver steps in tens.
    private static let accessibleStep: Double = 10

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// True while the slider is pressed or dragged. Gesture state, so it also resets when a drag is cut short without
    /// an end (the popover closing under the pointer), where an onEnded never runs.
    @GestureState private var held = false

    /// The press that began the drag, and its distance from the knob's centre if it landed on the knob. Held for the
    /// whole drag, so pressing the knob off-centre does not move the value. A press on the bare track holds zero, so
    /// the knob's centre jumps to the pointer. Keyed by the press, so a drag cut short without an end starts afresh.
    @State private var grip: (start: CGFloat, offset: CGFloat)?

    var body: some View {
        HStack(spacing: 10) {
            // Each sun is centred in a column as wide as the display icon, so the left one sits under the icon and the
            // track starts where the name does.
            Image(systemName: "sun.min.fill")
                .font(.system(size: 11))
                .foregroundStyle(Palette.tertiary)
                .frame(width: Metric.well)
                .accessibilityHidden(true)
            GeometryReader { proxy in
                let span = max(range.upperBound - range.lowerBound, 1)
                let fraction = (value - range.lowerBound) / span
                let travel = max(proxy.size.width - Self.knobWidth, 1)
                let x = Self.knobWidth / 2 + CGFloat(fraction) * travel
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.trackFill).frame(height: Self.trackHeight)
                    Capsule()
                        .fill(backlight ? Color.accentColor : Color.primary.opacity(0.4))
                        .frame(width: x, height: Self.trackHeight)
                    Capsule()
                        .fill(.white)
                        .frame(width: Self.knobWidth, height: Self.knobHeight)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        // Held, the white gives way to clear glass that refracts the track, as the system slider's
                        // knob does. The fade is on the white only: glass under an opacity draws nothing behind it.
                        .opacity(held ? 0 : 1)
                        .glassEffect(held ? .clear : .identity, in: .capsule)
                        .scaleEffect(held && !reduceMotion ? Self.heldScale : 1)
                        // Before the offset, so only the knob's look animates and the value still moves at once.
                        .animation(Motion.pick(.snappy(duration: 0.2), reduceMotion), value: held)
                        .offset(x: x - Self.knobWidth / 2)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($held) { _, held, _ in held = true }
                        .onChanged { drag in
                            let offset: CGFloat
                            if let grip, grip.start == drag.startLocation.x {
                                offset = grip.offset
                            } else {
                                let fromCentre = drag.startLocation.x - x
                                offset = abs(fromCentre) <= Self.knobWidth / 2 ? fromCentre : 0
                                grip = (drag.startLocation.x, offset)
                            }
                            let f = min(1, max(0, (drag.location.x - offset - Self.knobWidth / 2) / travel))
                            value = (range.lowerBound + Double(f) * span).rounded()
                        }
                        .onEnded { _ in grip = nil }
                )
            }
            .frame(height: Metric.hitTarget)
            Image(systemName: "sun.max.fill")
                .font(.system(size: 13))
                .foregroundStyle(Palette.tertiary)
                .frame(width: Metric.well)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(value)) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + Self.accessibleStep)
            case .decrement: value = max(range.lowerBound, value - Self.accessibleStep)
            @unknown default: break
            }
        }
    }
}

/// A round Liquid Glass button with a symbol: back, refresh, settings, quit. The label is the tooltip and the
/// VoiceOver name.
struct IconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    /// Square, so the circle stays round, and smaller than the control, so the control size sets the diameter.
    private static let glyphBox: CGFloat = 16

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: Self.glyphBox, height: Self.glyphBox)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        // No accent tint on the glass, as macOS glass buttons are meant to be set up.
        .tint(.clear)
        // About Metric.hitTarget across: 28 to 29pt measured on macOS 27.
        .controlSize(.large)
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Row hover: the content's own frame as a rounded rect, 6% fill (12% under Increase Contrast), inset 8pt from each
/// side. With 8pt below it as well the 12pt radius is concentric with the panel's 20pt corner. The pill is also the
/// hover area, so the pointer never lights it from outside.
struct HoverHighlight: ViewModifier {
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let pill = RoundedRectangle(cornerRadius: Metric.hoverRadius, style: .continuous)
        content
            .background(pill.fill(contrast == .increased ? Palette.hoverStrong : Palette.hover).opacity(hovering ? 1 : 0))
            .contentShape(pill)
            .onHover { inside in
                withAnimation(reduceMotion ? nil : Motion.hover) { hovering = inside }
            }
            .padding(.horizontal, Metric.hoverInset)
    }
}

extension View {
    func hoverHighlight() -> some View {
        modifier(HoverHighlight())
    }
}
