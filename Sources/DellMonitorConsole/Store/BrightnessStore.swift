import AppKit
import Observation

/// What the popover shows, and the only thing that changes displays.
///
/// A slider move sets a target. One writer per display sends the newest target (a fast drag collapses to the
/// latest value), then reads the display back, and the row shows what the display reported. While that is in flight
/// the row is `.pending`; it is never shown as done on the strength of the write alone.
@MainActor
@Observable
final class BrightnessStore {
    enum Phase: Equatable {
        case loading
        case ready
        case pending
        /// The write went through but the display did not confirm the level.
        case unverified
        case failed
    }

    struct Row: Identifiable, Equatable {
        let id: String
        var name: String
        var kind: BackendKind
        var percent: Int
        var phase: Phase

        var minimum: Int { kind == .software ? SoftwareBackend.floor : 0 }
    }

    private(set) var rows: [Row] = []
    private(set) var lastUsedID: String? = Preferences.lastUsedDisplay

    private final class Controller {
        let backend: any BrightnessBackend
        var target: Int?
        var writer: Task<Void, Never>?

        init(backend: any BrightnessBackend) {
            self.backend = backend
        }
    }

    private var controllers: [String: Controller] = [:]
    private var refreshTask: Task<Void, Never>?
    private var debounce: Task<Void, Never>?
    private var lastRefresh: Date?
    private var started = false

    // MARK: - Lifecycle

    func start() {
        guard !started else { return }
        started = true
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        CGDisplayRegisterReconfigurationCallback({ _, flags, context in
            // Reconfiguration arrives as a begin/end pair; only the end carries the new layout.
            guard !flags.contains(.beginConfigurationFlag), let context else { return }
            let store = Unmanaged<BrightnessStore>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in store.scheduleRefresh(after: .seconds(1)) }
        }, pointer)
        // A display's DDC engine is not ready the instant the Mac wakes.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scheduleRefresh(after: .seconds(3)) }
        }
        refresh()
    }

    /// Called when the popover opens: the monitor's own buttons may have changed a level since the last read.
    func refreshIfStale() {
        if let lastRefresh, Date().timeIntervalSince(lastRefresh) < 10 { return }
        refresh()
    }

    /// Never closer than two seconds to the previous refresh, so a burst of reconfiguration events (or our own gamma
    /// writes, if macOS reports them) cannot turn into a loop of DDC probes.
    func scheduleRefresh(after delay: Duration) {
        debounce?.cancel()
        var wait = delay
        if let lastRefresh {
            let cooldown = 2 - Date().timeIntervalSince(lastRefresh)
            if cooldown > 0 { wait = max(delay, .seconds(cooldown)) }
        }
        debounce = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    /// Re-enumerates displays and re-reads every level. Which transport a display uses is decided here, every
    /// time, so a monitor that starts answering DDC/CI is picked up without restarting the app.
    func refresh() {
        refreshTask?.cancel()
        let displays = DisplayCatalog.current()
        refreshTask = Task { [weak self] in
            let resolved = await withTaskGroup(of: (Int, any BrightnessBackend, Int?).self) { group in
                for (index, display) in displays.enumerated() {
                    group.addTask {
                        let (backend, level) = await Self.resolve(display)
                        return (index, backend, level)
                    }
                }
                var out: [(Int, any BrightnessBackend, Int?)] = []
                for await item in group { out.append(item) }
                return out
            }
            guard !Task.isCancelled, let self else { return }
            self.apply(displays: displays, resolved: resolved.sorted { $0.0 < $1.0 })
        }
    }

    /// DDC/CI where the display gives a validated answer, otherwise a software dim. The probe is a real read.
    private nonisolated static func resolve(_ display: DisplayInfo) async -> (any BrightnessBackend, Int?) {
        if display.isBuiltIn, BuiltInBackend.isAvailable {
            let backend = BuiltInBackend(cgID: display.cgID)
            return (backend, await backend.read())
        }
        if !display.isBuiltIn, let service = display.service {
            let ddc = DDCBackend(display: DDCDisplay(service: service))
            if let level = await ddc.read() { return (ddc, level) }
        }
        let software = SoftwareBackend(cgID: display.cgID, id: display.id)
        return (software, await software.read())
    }

    private func apply(displays: [DisplayInfo], resolved: [(Int, any BrightnessBackend, Int?)]) {
        var next: [Row] = []
        var kept: [String: Controller] = [:]

        for (index, backend, level) in resolved {
            let display = displays[index]
            if let busy = controllers[display.id], busy.writer != nil,
               let row = rows.first(where: { $0.id == display.id }) {
                // A write is in flight: the row is the user's, not the refresh's.
                kept[display.id] = busy
                next.append(row)
                continue
            }
            kept[display.id] = Controller(backend: backend)
            next.append(Row(
                id: display.id,
                name: display.name,
                kind: backend.kind,
                percent: level ?? 100,
                phase: level == nil && backend.kind != .software ? .failed : .ready
            ))
        }

        controllers = kept
        rows = next.sorted { lhs, rhs in
            if (lhs.kind == .builtIn) != (rhs.kind == .builtIn) { return lhs.kind == .builtIn }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        lastRefresh = Date()

        // Gamma tables are reset by a reconfiguration, so a software dim is applied again.
        for row in rows where row.kind == .software {
            set(row.percent, for: row.id)
        }
    }

    // MARK: - Changing a level

    /// The slider. The row moves with the pointer at once; its phase says it is not confirmed yet.
    func set(_ percent: Int, for id: String) {
        guard let index = rows.firstIndex(where: { $0.id == id }), let controller = controllers[id] else { return }
        let value = min(100, max(rows[index].minimum, percent))
        rows[index].percent = value
        rows[index].phase = controller.backend.kind == .software ? .ready : .pending
        controller.target = value
        lastUsedID = id
        Preferences.lastUsedDisplay = id
        drain(controller, id: id)
    }

    /// The display the menu bar glyph shows and a scroll over it changes: the external display you used last, else the
    /// first external one. The built-in panel is never it, so the glyph is always about the monitor.
    var focus: Row? {
        let externals = rows.filter { $0.kind != .builtIn }
        return lastUsedID.flatMap { id in externals.first { $0.id == id } } ?? externals.first
    }

    /// Scroll over the menu bar icon. Returns what to show: the display it landed on and its new level.
    @discardableResult
    func nudge(by delta: Int) -> (name: String, percent: Int)? {
        guard let row = focus else { return nil }
        let value = min(100, max(row.minimum, row.percent + delta))
        set(value, for: row.id)
        return (row.name, value)
    }

    private func drain(_ controller: Controller, id: String) {
        guard controller.writer == nil else { return }
        controller.writer = Task { [weak self, weak controller] in
            guard let controller else { return }
            var accepted = true
            var lastTarget = 0
            while let target = controller.target {
                controller.target = nil
                lastTarget = target
                accepted = await controller.backend.write(target)
                if !accepted { break }
                try? await Task.sleep(for: controller.backend.writeSpacing)
            }

            // A display can hand back the reply it latched before the write, so the read-back is repeated until
            // it shows the level that was set. If it never does, the row says so instead of claiming success.
            var confirmed: Int?
            var matched = false
            if accepted, controller.backend.kind != .software {
                for attempt in 0..<3 {
                    if attempt > 0 { try? await Task.sleep(for: .milliseconds(150)) }
                    confirmed = await controller.backend.read()
                    if let confirmed, abs(confirmed - lastTarget) <= 1 {
                        matched = true
                        break
                    }
                }
            }

            guard let self else { return }
            controller.writer = nil
            guard let index = self.rows.firstIndex(where: { $0.id == id }) else { return }
            if controller.target != nil {
                // The user moved again while we were reading back: go around once more.
                self.drain(controller, id: id)
                return
            }
            if !accepted {
                self.rows[index].phase = .failed
            } else if controller.backend.kind == .software {
                self.rows[index].phase = .ready
            } else if let confirmed {
                self.rows[index].percent = confirmed
                self.rows[index].phase = matched ? .ready : .unverified
            } else {
                self.rows[index].phase = .unverified
            }
        }
    }

    var needsAttention: Bool {
        rows.contains { $0.phase == .failed }
    }
}
