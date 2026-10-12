import SwiftUI

struct PopoverRoot: View {
    @Environment(BrightnessStore.self) private var store
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    let onQuit: () -> Void
    let onHeightChange: (CGFloat) -> Void

    var body: some View {
        GlassPopover {
            VStack(spacing: 0) {
                header
                if store.rows.isEmpty {
                    Text("No displays found")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.secondary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                } else {
                    Card {
                        ForEach(Array(store.rows.enumerated()), id: \.element.id) { index, row in
                            if index > 0 {
                                Hairline().padding(.horizontal, Metric.side)
                            }
                            DisplayRow(row: row)
                        }
                    }
                }
                footer
            }
            .padding(.bottom, Metric.groupInset)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeightChange($0) }
        }
    }

    private var header: some View {
        HStack {
            Text("Displays")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.label)
            Spacer()
            Button {
                store.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.secondary)
                    .frame(width: Metric.well, height: Metric.well)
                    .background(Circle().fill(Palette.wellFill))
            }
            .buttonStyle(.plain)
            .help("Check displays again")
            .accessibilityLabel("Check displays again")
        }
        .padding(.horizontal, Metric.side)
        .frame(height: Metric.header)
    }

    private var footer: some View {
        HStack {
            Toggle(isOn: $launchAtLogin) {
                Text("Open at login")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.secondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .onChange(of: launchAtLogin) { _, wanted in
                do {
                    try LaunchAtLogin.setEnabled(wanted)
                } catch {
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
            }
            Spacer()
            Button("Quit", action: onQuit)
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondary)
                .keyboardShortcut("q")
        }
        .padding(.horizontal, Metric.side)
        .frame(height: Metric.header)
    }
}
