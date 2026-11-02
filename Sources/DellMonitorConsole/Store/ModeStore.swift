import Observation

/// The True Tone, Dark Mode and Night Shift switches in the popover.
///
/// A toggle flips the row at once and marks it `.pending`; the row is never shown as done on the strength of the
/// write alone. The mode is read back, and the row settles on what the system reported.
@MainActor
@Observable
final class ModeStore {
    enum Phase: Equatable {
        case ready
        case pending
        /// The write was not confirmed by a read-back; the row shows what the system reported.
        case failed
    }

    struct Mode: Identifiable, Equatable {
        let id: ModeID
        var isOn: Bool
        var until: Until?
        var phase: Phase
    }

    /// Only the modes this Mac has, in `ModeID.allCases` order.
    private(set) var modes: [Mode] = []

    private let backends: [ModeID: any ModeBackend]
    private var refreshing = false
    /// Modes whose toggle settled since the running refresh began. Its read may predate that, so it must not overwrite them.
    private var toggled: Set<ModeID> = []

    init() {
        backends = Dictionary(ModeBackends.all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - Reading

    func refresh() {
        guard !refreshing else { return }
        refreshing = true
        toggled = []
        let backends = ModeID.allCases.compactMap { self.backends[$0] }
        Task { [weak self] in
            var found: [ModeID: ModeReading] = [:]
            for backend in backends {
                guard await backend.isAvailable(), let reading = await backend.read() else { continue }
                found[backend.id] = reading
            }

            guard let self else { return }
            self.refreshing = false
            let current = Dictionary(self.modes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            self.modes = ModeID.allCases.compactMap { id in
                if let mode = current[id], mode.phase == .pending || self.toggled.contains(id) { return mode }
                return found[id].map { Mode(id: id, isOn: $0.isOn, until: $0.until, phase: .ready) }
            }
        }
    }

    // MARK: - Changing a mode

    func toggle(_ id: ModeID) {
        guard let index = modes.firstIndex(where: { $0.id == id }), modes[index].phase != .pending,
              let backend = backends[id] else { return }
        let previous = modes[index].isOn
        let previousUntil = modes[index].until
        let target = !previous
        modes[index].isOn = target
        // The old "until" belongs to the old state. A change by hand inside a schedule always reads back as "Until
        // Tomorrow", and with no schedule as plain On or Off, so that is what the pending row shows: the text keeps its
        // wording and line count until the reading arrives, and a different reading still replaces it.
        modes[index].until = previousUntil == nil ? nil : .tomorrow
        modes[index].phase = .pending

        Task { [weak self] in
            _ = await backend.write(target)

            // The system can take a moment to apply a change, so the read-back is repeated until it shows the
            // requested state. If it never does, the row falls back to what was last reported.
            var reported: ModeReading?
            for attempt in 0..<3 {
                if attempt > 0 { try? await Task.sleep(for: .milliseconds(100)) }
                if let value = await backend.read() { reported = value }
                if reported?.isOn == target { break }
            }

            guard let self else { return }
            self.toggled.insert(id)
            guard let index = self.modes.firstIndex(where: { $0.id == id }) else { return }
            if let reported, reported.isOn == target {
                self.modes[index].isOn = target
                self.modes[index].until = reported.until
                self.modes[index].phase = .ready
            } else {
                self.modes[index].isOn = reported?.isOn ?? previous
                self.modes[index].until = reported == nil ? previousUntil : reported?.until
                self.modes[index].phase = .failed
            }
        }
    }
}
