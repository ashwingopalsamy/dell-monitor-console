import SwiftUI

/// A row on a settings-style screen: a title, and a control or a chevron at the trailing edge.
struct SettingsRow<Control: View>: View {
    let title: String
    var symbol: String?
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 10) {
            if let symbol {
                Well {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.label)
                }
            }
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Palette.label)
            Spacer(minLength: 8)
            control
        }
        .padding(.horizontal, Metric.side)
        .frame(height: 48)
        .contentShape(Rectangle())
    }
}

struct SettingsScreen: View {
    @Environment(PopoverNavigator.self) private var navigator
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Settings", back: { navigator.screen = .home }) { EmptyView() }
            Hairline().padding(.horizontal, Metric.side)
            SettingsRow(title: "Open at login", symbol: "power.circle") {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { _, wanted in
                        do {
                            try LaunchAtLogin.setEnabled(wanted)
                        } catch {
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
            }
            Hairline().padding(.horizontal, Metric.side)
            Button { navigator.screen = .faq } label: {
                SettingsRow(title: "FAQ", symbol: "questionmark.circle") { Chevron() }
            }
            .buttonStyle(.plain)
            Hairline().padding(.horizontal, Metric.side)
            Button { navigator.screen = .about } label: {
                SettingsRow(title: "About", symbol: "info.circle") { Chevron() }
            }
            .buttonStyle(.plain)
            Color.clear.frame(height: Metric.groupInset)
        }
    }
}

struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Palette.tertiary)
            .accessibilityHidden(true)
    }
}
