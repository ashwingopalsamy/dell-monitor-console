import SwiftUI

/// One display: name, level, and its slider. A row shows exceptions only (software dimming, unconfirmed, failed);
/// a display under hardware control carries no glyph.
struct DisplayRow: View {
    @Environment(BrightnessStore.self) private var store
    let row: BrightnessStore.Row

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Well {
                    Image(systemName: row.kind == .builtIn ? "laptopcomputer" : "display")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.label)
                }
                .padding(.trailing, 8)
                Text(row.name)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.label)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                if let status {
                    Image(systemName: status.symbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(status.isAttention ? Palette.attention : Palette.secondary)
                        .help(status.help)
                        .padding(.trailing, 8)
                        .accessibilityHidden(true)
                }
                Text("\(row.percent)%")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(row.phase == .pending ? Palette.tertiary : Palette.secondary)
                    .frame(minWidth: 36, alignment: .trailing)
            }
            .frame(height: Metric.nameRow)
            CapsuleSlider(value: level, range: Double(row.minimum)...100, width: Metric.content, label: row.name)
                .padding(.bottom, 4)
        }
        .padding(.horizontal, Metric.side)
        .hoverHighlight()
        .accessibilityElement(children: .contain)
        .accessibilityHint(accessibilityHint)
    }

    private var level: Binding<Double> {
        Binding(
            get: { Double(row.percent) },
            set: { store.set(Int($0), for: row.id) }
        )
    }

    private struct Status {
        let symbol: String
        let help: String
        var isAttention = false
    }

    private var status: Status? {
        switch (row.phase, row.kind) {
        case (.failed, _):
            Status(symbol: "exclamationmark.triangle.fill",
                   help: "This display did not accept the change.", isAttention: true)
        case (.unverified, _):
            Status(symbol: "questionmark.circle", help: "Set, but the display did not confirm the level.")
        case (_, .software):
            Status(symbol: "circle.lefthalf.filled",
                   help: "Software dimming. This display does not answer DDC/CI, so the picture is dimmed, not the backlight.")
        default:
            nil
        }
    }

    private var accessibilityHint: String {
        switch row.kind {
        case .software: "Software dimming; the backlight is unchanged"
        case .ddc, .builtIn: ""
        }
    }
}
