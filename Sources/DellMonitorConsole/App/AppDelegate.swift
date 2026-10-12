import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Strong references: the controller holds the only pointer to its status item and window.
    private var store: BrightnessStore?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let store = BrightnessStore()
        self.store = store
        let statusItem = StatusItemController(store: store)
        self.statusItem = statusItem
        store.start()
        if CommandLine.arguments.contains("--show") {
            // The status item needs a run-loop turn to get its window before the popover can anchor to it.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                let names: [String: PopoverNavigator.Screen] = ["settings": .settings, "faq": .faq, "about": .about]
                let arguments = CommandLine.arguments
                let after = arguments.firstIndex(of: "--show").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
                statusItem.showPopover(screen: after.flatMap { names[$0] } ?? .home)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // macOS restores gamma tables when the process exits; this makes it immediate and certain.
        SoftwareBackend.restoreAll()
    }
}
