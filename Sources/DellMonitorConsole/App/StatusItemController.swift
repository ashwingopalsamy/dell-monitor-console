import AppKit
import Observation

private let glyphPointSize: CGFloat = 15
private let badgeDiameter: CGFloat = 6
private let badgeGap: CGFloat = 1.5

// NSObject is required: the status button sends its action through the Objective-C runtime.
@MainActor
final class StatusItemController: NSObject {
    // Fixed, so the item never shifts its neighbours except for the moment a scroll shows the new level.
    private static let itemWidth: CGFloat = 40
    private static let feedbackWidth: CGFloat = 72
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

    init(store: BrightnessStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: StatusItemController.itemWidth)
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

    /// Opens the popover without a click, for `--show` at launch.
    func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        popover.show(below: button)
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

    /// The new level, in the item itself, for a moment. The popover is not opened for a scroll.
    private func showFeedback(_ text: String, about name: String) {
        guard let button = statusItem.button else { return }
        statusItem.length = Self.feedbackWidth
        button.title = text
        button.imagePosition = .imageLeading
        button.toolTip = name
        feedback?.cancel()
        feedback = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.feedbackDuration)
            guard !Task.isCancelled, let self else { return }
            self.statusItem.length = Self.itemWidth
            self.refreshButton()
        }
    }

    // MARK: - Button

    // Observation reports changes before they land, so the re-read is deferred to the next main-actor turn and
    // tracking is re-armed from there.
    private func trackSnapshots() {
        withObservationTracking {
            if feedback == nil || feedback?.isCancelled == true { refreshButton() }
        } onChange: { [weak self] in
            Task { @MainActor in self?.trackSnapshots() }
        }
    }

    private func refreshButton() {
        guard let button = statusItem.button else { return }
        let attention = store.needsAttention
        button.image = attention ? Self.badgedGlyph("sun.max") : Self.glyph("sun.max")
        button.title = ""
        button.imagePosition = .imageOnly
        let summary = attention ? "a display needs attention" : "\(store.rows.count) displays"
        button.setAccessibilityLabel("Dell Monitor Console, \(summary)")
        button.toolTip = "Brightness"
    }

    private nonisolated static func glyph(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: glyphPointSize, weight: .regular))
        image?.isTemplate = true
        return image
    }

    /// The glyph with a 6pt dot in its top-right corner, cut out of the glyph by a 1.5pt gap. Still a template.
    private static func badgedGlyph(_ name: String) -> NSImage? {
        guard let size = glyph(name)?.size else { return nil }
        let image = NSImage(size: size, flipped: false) { rect in
            guard let base = glyph(name) else { return false }
            base.draw(in: rect)
            let dot = NSRect(x: rect.maxX - badgeDiameter, y: rect.maxY - badgeDiameter,
                             width: badgeDiameter, height: badgeDiameter)
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: dot.insetBy(dx: -badgeGap, dy: -badgeGap)).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            NSColor.black.setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
