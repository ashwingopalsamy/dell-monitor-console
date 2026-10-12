import Observation

/// Which screen the popover shows. It lives as long as the window, and is put back to the home screen whenever the
/// popover closes, so it always opens on the displays.
@MainActor
@Observable
final class PopoverNavigator {
    enum Screen {
        case home, settings, faq, about
    }

    var screen: Screen = .home
}
