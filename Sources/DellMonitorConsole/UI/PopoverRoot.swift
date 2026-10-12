import SwiftUI

struct PopoverRoot: View {
    @Environment(PopoverNavigator.self) private var navigator
    let onQuit: () -> Void
    let onHeightChange: (CGFloat) -> Void

    var body: some View {
        GlassPopover {
            ZStack {
                switch navigator.screen {
                case .home: HomeScreen(onQuit: onQuit)
                case .settings: SettingsScreen()
                case .faq: FaqScreen()
                case .about: AboutScreen()
                }
            }
            .transition(.opacity)
            .id(navigator.screen)
            .animation(Motion.push, value: navigator.screen)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeightChange($0) }
        }
    }
}

/// The title line of a screen: a title, and the round buttons that belong to it.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    var back: (() -> Void)?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            if let back {
                IconButton(symbol: "chevron.left", label: "Back", action: back)
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.label)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, Metric.side)
        .frame(height: Metric.header)
    }
}

/// The displays, one section each. Refresh, settings and quit sit in the header, where Control Center keeps its own.
struct HomeScreen: View {
    @Environment(BrightnessStore.self) private var store
    @Environment(PopoverNavigator.self) private var navigator
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Displays") {
                IconButton(symbol: "arrow.clockwise", label: "Check displays again") { store.refresh() }
                IconButton(symbol: "gearshape", label: "Settings") { navigator.screen = .settings }
                IconButton(symbol: "power", label: "Quit", action: onQuit)
            }
            if store.rows.isEmpty {
                Text("No displays found")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.secondary)
                    .frame(maxWidth: .infinity, minHeight: 72)
            } else {
                ForEach(Array(store.rows.enumerated()), id: \.element.id) { index, row in
                    Hairline().padding(.horizontal, Metric.side)
                    DisplayRow(row: row)
                }
            }
            Color.clear.frame(height: Metric.groupInset)
        }
    }
}
