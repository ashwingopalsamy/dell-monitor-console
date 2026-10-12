import SwiftUI

/// The questions people actually ask, short. The longer answers are on the project's site.
struct FaqScreen: View {
    @Environment(PopoverNavigator.self) private var navigator
    @State private var open: Int?

    private static let entries: [(question: String, answer: String)] = [
        ("What does \"Software dimming\" mean?",
         "The display did not answer DDC/CI, so its picture is dimmed through the gamma table. The backlight does not change, and the dim ends when the app quits."),
        ("What does the question mark mean?",
         "The write went through, but the display did not report the new level back. The app shows a level as set only once the display has confirmed it."),
        ("Why does it need no permissions?",
         "Brightness goes straight to the display over its cable. Scrolling over the menu bar icon is received by the app's own status item, so there is no Accessibility request."),
        ("Does it work with other brands?",
         "It is verified on two Dell models. Any display that answers DDC/CI should work, and one that does not falls back to software dimming."),
        ("Can it run next to Dell's app?",
         "Yes. Both talk to a display over the same channel, so an answer meant for one can reach the other. The app checks every reply and asks again, so the cost is an occasional retry."),
        ("What if macOS removes the private APIs?",
         "DDC/CI and the built-in brightness use private macOS interfaces, loaded at runtime. If one goes away, displays fall back to software dimming and the app keeps running."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "FAQ", back: { navigator.screen = .settings }) { EmptyView() }
            ForEach(Array(Self.entries.enumerated()), id: \.offset) { index, entry in
                Hairline().padding(.horizontal, Metric.side)
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(Motion.push) { open = open == index ? nil : index }
                    } label: {
                        HStack(spacing: 10) {
                            Text(entry.question)
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.label)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Palette.tertiary)
                                .rotationEffect(.degrees(open == index ? 180 : 0))
                        }
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if open == index {
                        Text(entry.answer)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 14)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, Metric.side)
            }
            Color.clear.frame(height: Metric.groupInset)
        }
    }
}
