import SwiftUI

/// One display, as Control Center draws one: its name, how it is being controlled, the level, and the slider.
struct DisplayRow: View {
    @Environment(BrightnessStore.self) private var store
    let row: BrightnessStore.Row

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Well {
                    Image(systemName: row.kind == .builtIn ? "laptopcomputer" : "display")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.label)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.label)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    HStack(spacing: 4) {
                        if let symbol = note.symbol {
                            Image(systemName: symbol)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(note.attention ? Palette.attention : Palette.secondary)
                        }
                        Text(note.text)
                            .font(.system(size: 11))
                            .foregroundStyle(note.attention ? Palette.attention : Palette.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Text("\(row.percent)%")
                    .font(.system(size: 14, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(row.phase == .pending ? Palette.tertiary : Palette.label)
            }
            BrightnessSlider(value: level, range: Double(row.minimum)...100, backlight: row.kind != .software, label: row.name)
        }
        .padding(.horizontal, Metric.side)
        .padding(.vertical, 14)
        .accessibilityElement(children: .contain)
        .help(note.help)
    }

    private var level: Binding<Double> {
        Binding(
            get: { Double(row.percent) },
            set: { store.set(Int($0), for: row.id) }
        )
    }

    private struct Note {
        var symbol: String?
        var text: String
        var help = ""
        var attention = false
    }

    /// The line under the name: how the display is controlled, or what went wrong with it.
    private var note: Note {
        switch row.phase {
        case .failed:
            return Note(symbol: "exclamationmark.triangle.fill", text: "Did not accept the change",
                        help: "The display did not accept the change.", attention: true)
        case .unverified:
            return Note(symbol: "questionmark.circle", text: "Set, not confirmed",
                        help: "The write went through, but the display did not confirm the level.")
        default:
            break
        }
        switch row.kind {
        case .ddc:
            return Note(text: "Backlight, over DDC/CI")
        case .builtIn:
            return Note(text: "Backlight, through macOS")
        case .software:
            return Note(symbol: "circle.lefthalf.filled", text: "Software dimming",
                        help: "This display does not answer DDC/CI, so the picture is dimmed, not the backlight.")
        }
    }
}
