import AppKit
import Observation

// NSObject is required: the status button sends its action through the Objective-C runtime.
@MainActor
final class StatusItemController: NSObject {
    private static let feedbackDuration: Duration = .milliseconds(1200)
    /// Trackpad points of scrolling per 1%, and percent per notch of a wheel.
    private static let pointsPerPercent: CGFloat = 6
    private static let percentPerNotch = 5

    private let store: BrightnessStore
    private let statusItem: NSStatusItem
    private let popover: PopoverWindow
    private var scrollMonitor: Any?
    private var scrollRemainder: CGFloat = 0
    private var feedback: Task<Void, Never>?
    /// The level shown beside the glyph for a moment after a scroll. nil the rest of the time.
    private var feedbackText: String?

    init(store: BrightnessStore) {
        self.store = store
        // Only as wide as the glyph. A scroll adds the new level beside it for a moment.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = PopoverWindow(store: store)
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imageHugsTitle = true
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
        }
        popover.onVisibilityChange = { [weak self] isShown in
            self?.statusItem.button?.highlight(isShown)
        }
        // Scrolls over our own status item are delivered to a local monitor, because the item's window is ours.
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, event.window === self.statusItem.button?.window else { return event }
            self.handleScroll(event)
            return nil
        }
        trackSnapshots()
    }

    /// Opens the popover without a click, for `--show [settings|faq|about]` at launch.
    func showPopover(screen: PopoverNavigator.Screen = .home) {
        guard let button = statusItem.button, !popover.isShown else { return }
        popover.show(below: button, screen: screen)
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.hide()
        } else {
            popover.show(below: button)
        }
    }

    // MARK: - Scroll

    private func handleScroll(_ event: NSEvent) {
        var steps = 0
        if event.hasPreciseScrollingDeltas {
            // Trackpad: accumulate, so a slow scroll still moves and a fast one does not leap. Momentum is ignored.
            guard event.momentumPhase == [] else { return }
            // Physical "up" raises brightness whatever the natural-scrolling setting is.
            let up = event.isDirectionInvertedFromDevice ? -event.scrollingDeltaY : event.scrollingDeltaY
            scrollRemainder += up
            steps = Int(scrollRemainder / Self.pointsPerPercent)
            scrollRemainder -= CGFloat(steps) * Self.pointsPerPercent
        } else {
            let up = event.isDirectionInvertedFromDevice ? -event.scrollingDeltaY : event.scrollingDeltaY
            steps = up == 0 ? 0 : (up > 0 ? Self.percentPerNotch : -Self.percentPerNotch)
        }
        guard steps != 0, let result = store.nudge(by: steps) else { return }
        showFeedback("\(result.percent)%", about: result.name)
    }

    /// The new level, beside the glyph, for a moment. The popover is not opened for a scroll.
    private func showFeedback(_ text: String, about name: String) {
        feedbackText = text
        refreshButton()
        statusItem.button?.toolTip = name
        feedback?.cancel()
        feedback = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.feedbackDuration)
            guard !Task.isCancelled, let self else { return }
            self.feedbackText = nil
            self.refreshButton()
        }
    }

    // MARK: - Button

    // Observation reports changes before they land, so the re-read is deferred to the next main-actor turn and tracking
    // is re-armed from there.
    private func trackSnapshots() {
        withObservationTracking {
            refreshButton()
        } onChange: { [weak self] in
            Task { @MainActor in self?.trackSnapshots() }
        }
    }

    /// The glyph follows the external monitor you last used, never the built-in panel: its brightness lights the rays,
    /// and the centre dot says a monitor is there at all.
    private func refreshButton() {
        guard let button = statusItem.button else { return }
        let focus = store.focus
        button.image = StatusIcon.image(level: focus?.percent, attention: store.needsAttention)
        if let feedbackText {
            button.title = feedbackText
            button.imagePosition = .imageLeading
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
            button.toolTip = focus.map { "\($0.name), \($0.percent)%" } ?? "No external display found"
        }
        let summary = focus.map { "\($0.name), \($0.percent) percent" } ?? "no displays found"
        button.setAccessibilityLabel("Dell Monitor Console, \(summary)")
    }
}
