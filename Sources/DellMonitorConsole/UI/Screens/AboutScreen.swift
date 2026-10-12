import SwiftUI
import AppKit

struct AboutScreen: View {
    @Environment(PopoverNavigator.self) private var navigator

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "About", back: { navigator.screen = .settings }) { EmptyView() }
            VStack(spacing: 6) {
                Image(nsImage: AppIconRenderer.image(size: 72))
                    .resizable()
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)
                Text("Dell Monitor Console")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.label)
                if !version.isEmpty {
                    Text("Version \(version)")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.secondary)
                }
                Text("Not affiliated with, endorsed by or supported by Dell.")
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.tertiary)
                    .padding(.top, 6)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 14)
            .padding(.bottom, 18)
            link("Website", symbol: "safari", to: "https://apps.ashwingopalsamy.in/dell-monitor-console/") // allow-url
            link("Source code", symbol: "chevron.left.forwardslash.chevron.right", to: "https://github.com/ashwingopalsamy/dell-monitor-console") // allow-url
            link("PolyForm Noncommercial 1.0.0", symbol: "doc.text", to: "https://github.com/ashwingopalsamy/dell-monitor-console/blob/main/LICENSE") // allow-url
            Text("© 2026 Ashwin Gopalsamy")
                .font(.system(size: 11))
                .foregroundStyle(Palette.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
    }

    /// A row that hands a link to the user's browser. The app itself never opens a connection.
    private func link(_ title: String, symbol: String, to address: String) -> some View {
        VStack(spacing: 0) {
            Hairline().padding(.horizontal, Metric.side)
            Button {
                if let url = URL(string: address) { NSWorkspace.shared.open(url) }
            } label: {
                SettingsRow(title: title, symbol: symbol) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
