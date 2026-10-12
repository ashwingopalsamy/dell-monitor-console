import SwiftUI

@main
struct DellMonitorConsoleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Command-line modes run before any UI starts and exit when done:
        //   --list                       each display, how it is controlled, its level
        //   --set <name> <percent>       set the first display whose name contains <name>, print the result
        let arguments = CommandLine.arguments
        // Build tooling: `--render-icon <file.png> [pixels] [full|tile|glyph] [level 0...1]` writes the app icon (or
        // one layer of it) and exits. scripts/bundle.sh uses it to make AppIcon.icns.
        if let flag = arguments.firstIndex(of: "--render-icon"), arguments.indices.contains(flag + 1) {
            let pixels = arguments.indices.contains(flag + 2) ? Int(arguments[flag + 2]) ?? 1024 : 1024
            let layer = arguments.indices.contains(flag + 3)
                ? AppIconRenderer.Layer(rawValue: arguments[flag + 3]) ?? .full : .full
            let level = arguments.indices.contains(flag + 4) ? Double(arguments[flag + 4]) ?? 0.75 : 0.75
            _ = NSApplication.shared
            guard let data = AppIconRenderer.pngData(pixels: pixels, layer: layer, level: level),
                  (try? data.write(to: URL(fileURLWithPath: arguments[flag + 1]))) != nil else { exit(1) }
            exit(0)
        }
        if arguments.contains("--list") {
            Self.runHeadless { store in
                for row in store.rows {
                    print("\(row.name)\t\(row.kind)\t\(row.percent)%\t\(row.phase)")
                }
                if store.rows.isEmpty { print("no displays") }
                return 0
            }
        } else if let flag = arguments.firstIndex(of: "--set"), arguments.indices.contains(flag + 2),
                  let percent = Int(arguments[flag + 2]) {
            let name = arguments[flag + 1]
            Self.runHeadless { store in
                guard let row = store.rows.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) else {
                    print("no display matches \(name)")
                    return 1
                }
                store.set(percent, for: row.id)
                // Up to four seconds for the write and its read-back.
                for _ in 0..<40 {
                    try? await Task.sleep(for: .milliseconds(100))
                    if store.rows.first(where: { $0.id == row.id })?.phase != .pending { break }
                }
                guard let result = store.rows.first(where: { $0.id == row.id }) else { return 1 }
                print("\(result.name)\t\(result.kind)\t\(result.percent)%\t\(result.phase)")
                return result.phase == .failed ? 1 : 0
            }
        }
    }

    /// Enumerates the displays, runs `work`, exits with its status. Never returns.
    private static func runHeadless(_ work: @escaping @MainActor (BrightnessStore) async -> Int32) {
        _ = NSApplication.shared
        Task { @MainActor in
            let store = BrightnessStore()
            store.refresh()
            // One probe is up to a second or two per display, and they run side by side.
            for _ in 0..<80 {
                try? await Task.sleep(for: .milliseconds(100))
                if !store.rows.isEmpty { break }
            }
            exit(await work(store))
        }
        RunLoop.main.run()
    }

    var body: some Scene {
        // A menu bar app has no main window. The Settings scene only satisfies the App protocol.
        Settings { EmptyView() }
    }
}
