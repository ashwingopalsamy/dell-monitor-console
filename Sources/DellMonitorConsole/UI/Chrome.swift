import SwiftUI
import AppKit

/// The menu bar popover body: Liquid Glass, 320pt wide, squircle radius 20. The app hosts it in a clear panel, so
/// it draws no window background of its own. The content is pinned to the top, so the panel never has to resize.
struct GlassPopover<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            // The panel never becomes key, so a focus ring can only be spurious.
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

/// Neutral 24pt symbol well. No hue, ever. Decorative: the row it sits in names the display.
struct Well<Glyph: View>: View {
    @ViewBuilder var glyph: Glyph

    var body: some View {
        glyph
            .frame(width: Metric.well, height: Metric.well)
            .background(Circle().fill(Palette.wellFill))
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
    /// VoiceOver steps in tens.
    private static let accessibleStep: Double = 10

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.min.fill")
                .font(.system(size: 11))
                .foregroundStyle(Palette.tertiary)
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
                        .offset(x: x - Self.knobWidth / 2)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { drag in
                        let f = min(1, max(0, (drag.location.x - Self.knobWidth / 2) / travel))
                        value = (range.lowerBound + Double(f) * span).rounded()
                    }
                )
            }
            .frame(height: Metric.hitTarget)
            Image(systemName: "sun.max.fill")
                .font(.system(size: 13))
                .foregroundStyle(Palette.tertiary)
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

/// A round 28pt button with a symbol: refresh, settings, quit. The label is the tooltip and the VoiceOver name.
struct IconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(hovering ? Palette.label : Palette.secondary)
                .frame(width: Metric.hitTarget, height: Metric.hitTarget)
                .background(Circle().fill(hovering ? Palette.hoverStrong : Palette.wellFill))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Row hover: a rounded rect concentric with the card (radius 10, inset 2), 6% fill (12% under Increase Contrast).
struct HoverHighlight: ViewModifier {
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Metric.hoverRadius, style: .continuous)
                    .fill(contrast == .increased ? Palette.hoverStrong : Palette.hover)
                    .padding(.horizontal, Metric.hoverInset)
                    .padding(.vertical, 2)
                    .opacity(hovering ? 1 : 0)
            )
            .contentShape(Rectangle())
            .onHover { inside in
                withAnimation(reduceMotion ? nil : Motion.hover) { hovering = inside }
            }
    }
}

extension View {
    func hoverHighlight() -> some View {
        modifier(HoverHighlight())
    }
}
