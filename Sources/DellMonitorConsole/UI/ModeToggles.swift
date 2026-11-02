import SwiftUI
import AppKit

/// Dark Mode, Night Shift and True Tone as round toggles, measured from the Control Center Display panel. Only the
/// modes this Mac offers appear; with fewer than three the columns keep their width and centre as a group.
struct ModeToggleRow: View {
    @Environment(ModeStore.self) private var modes
    /// True when the row sits straight under a display's slider, with no hairline between.
    var afterSlider = false

    /// Three columns across the popover less 8pt a side: Control Center's 101.5pt pitch.
    private static let column = (Metric.popoverWidth - 16) / 3
    /// The knob ends 15pt above this row (5pt inside the slider's frame, then the row's 10pt padding), which is the 15pt
    /// Control Center leaves from knob to circle.
    private static let topAfterSlider: CGFloat = 0
    private static let topAfterHairline: CGFloat = 14
    /// Puts the last baseline 14pt above the hairline that follows.
    private static let bottom: CGFloat = 11.4

    var body: some View {
        // The three circles' glass renders together. Spacing 0, so they never merge.
        GlassEffectContainer(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(modes.modes) { mode in
                    ModeToggle(mode: mode)
                        .frame(width: Self.column)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, afterSlider ? Self.topAfterSlider : Self.topAfterHairline)
        .padding(.bottom, Self.bottom)
    }
}

/// One mode: a 36pt circle, its name and its state. Off is plain glass; on is glass tinted the mode's own colour. While
/// a change is pending the circle is faded and the state reads as the target. A change that did not land says so.
private struct ModeToggle: View {
    @Environment(ModeStore.self) private var modes
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let mode: ModeStore.Mode

    private static let diameter: CGFloat = 36
    private static let glyph: CGFloat = 18
    /// Circle to the name's baseline is 16pt, and an 11pt line puts its baseline 10.5pt down.
    private static let nameGap: CGFloat = 5.5
    /// Baselines 14pt apart, name to state and line to line: the 13.1pt line plus this.
    private static let leading: CGFloat = 0.9
    /// A long state wraps, centred, inside this.
    private static let stateWidth: CGFloat = 80
    /// The state line: white at 40% on dark glass, as Control Center draws it.
    private static let stateColor = Color.primary.opacity(0.4)
    private static let pendingOpacity = 0.55

    // The on fills as hue, saturation and brightness, so saturation is one number each. The popover's glass and the
    // circle's own glass lighten the tint, so these run richer than Control Center's: nudge saturation to match.
    /// #FFFFFF
    private static let darkModeFill = Color(.sRGB, red: 1, green: 1, blue: 1)
    /// About #F59936
    private static let nightShiftFill = Color(hue: 31 / 360, saturation: 0.78, brightness: 0.96)
    /// About #258CF9
    private static let trueToneFill = Color(hue: 211 / 360, saturation: 0.85, brightness: 0.976)

    private var title: String {
        switch mode.id {
        case .darkMode: "Dark Mode"
        case .nightShift: "Night Shift"
        case .trueTone: "True Tone"
        }
    }

    private var onFill: Color {
        switch mode.id {
        case .darkMode: Self.darkModeFill
        case .nightShift: Self.nightShiftFill
        case .trueTone: Self.trueToneFill
        }
    }

    /// Black on the white Dark Mode disc, white on the two colours, the label colour on the well.
    private var glyphColor: Color {
        guard mode.isOn else { return Palette.label }
        return mode.id == .darkMode ? .black : .white
    }

    /// The pending fade, for the tint and the glyph only.
    private var fade: Double {
        mode.phase == .pending ? Self.pendingOpacity : 1
    }

    /// Plain when off, tinted the mode's colour when on.
    private var glass: Glass {
        mode.isOn ? .regular.tint(onFill.opacity(fade)) : .regular
    }

    /// When the mode next changes on its own, worded as macOS words it.
    private var until: String? {
        switch mode.until {
        case nil: nil
        case .sunrise: "Sunrise"
        case .sunset: "Sunset"
        case .tomorrow: "Tomorrow"
        case let .time(hour, minute):
            Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now)?
                .formatted(Date.FormatStyle(date: .omitted, time: .shortened))
                ?? String(format: "%d:%02d", hour, minute)
        }
    }

    /// "On", "Off", or either until something: "On Until Tomorrow".
    private var state: String {
        let word = mode.isOn ? "On" : "Off"
        return until.map { "\(word) Until \($0)" } ?? word
    }

    /// The state as shown. The line always breaks after "Until", as Control Center breaks it, whatever the width.
    private var subtitle: String {
        guard mode.phase != .failed else { return "Did not change" }
        let word = mode.isOn ? "On" : "Off"
        return until.map { "\(word) Until\n\($0)" } ?? word
    }

    private var subtitleColor: Color {
        // Pending keeps the state colour: dimming the line and bringing it back reads as a flicker.
        mode.phase == .failed ? Palette.attention : Self.stateColor
    }

    var body: some View {
        Button { modes.toggle(mode.id) } label: {
            VStack(spacing: 0) {
                circle
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.label)
                    .lineLimit(1)
                    .padding(.top, Self.nameGap)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(subtitleColor)
                    .lineSpacing(Self.leading)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: Self.stateWidth)
                    .padding(.top, Self.leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(mode.phase == .failed ? "\(state), did not change" : state)
        .accessibilityAddTraits(.isToggle)
    }

    /// The glyph carries the glass as a modifier, so the glass draws behind it and the glyph stays sharp on top. Glass
    /// must see what is behind it: no fade or compositing group may hold it, so the pending fade is on the tint and
    /// the glyph.
    private var circle: some View {
        ModeGlyph(id: mode.id)
            .foregroundStyle(glyphColor)
            .opacity(fade)
            .frame(width: Self.glyph, height: Self.glyph)
            .frame(width: Self.diameter, height: Self.diameter)
            .glassEffect(glass, in: .circle)
            .animation(reduceMotion ? nil : Motion.hover, value: mode.isOn)
            .animation(reduceMotion ? nil : Motion.hover, value: mode.phase)
    }
}

/// The foot of Control Center's Display panel: opens the Displays pane of System Settings and closes the popover.
///
/// The hover pill is 28pt tall, 8pt in from each side and 8pt above the panel's edge, so its 12pt corners are concentric
/// with the panel's 20pt ones. It sits 4pt under the hairline above it.
struct DisplaySettingsRow: View {
    let onDismiss: () -> Void

    private static let gapBelowHairline: CGFloat = 4
    private static let pane = "x-apple.systempreferences:com.apple.Displays-Settings.extension"

    var body: some View {
        Button(action: openPane) {
            Text("Display Settings…")
                .font(.system(size: 13))
                .foregroundStyle(Palette.label)
                .frame(maxWidth: .infinity, alignment: .leading)
                // The pill's own inset comes out of the 16pt gutter, so the text keeps its place.
                .padding(.horizontal, Metric.side - Metric.hoverInset)
                .frame(height: Metric.rowPill)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight()
        .padding(.top, Self.gapBelowHairline)
        .padding(.bottom, Metric.groupInset)
    }

    private func openPane() {
        guard let url = URL(string: Self.pane) else { return }
        NSWorkspace.shared.open(url)
        onDismiss()
    }
}
