import AppKit
import Foundation
import ObjectiveC

/// The system-wide display modes the app can flip, in the order the macOS display panel lists them.
enum ModeID: String, CaseIterable, Sendable { case darkMode, nightShift, trueTone }

/// When a mode next changes on its own, worded as macOS words it ("On Until Sunrise").
enum Until: Equatable, Sendable { case sunrise, sunset, tomorrow, time(hour: Int, minute: Int) }

/// A mode as the system reports it. `until` is best effort: nil whenever its meaning is unclear, which reads as plain On or Off.
struct ModeReading: Equatable, Sendable { var isOn: Bool; var until: Until? }

protocol ModeBackend: Sendable {
    var id: ModeID { get }
    /// False when this Mac or this macOS build has no way to drive the mode.
    func isAvailable() async -> Bool
    /// The mode as the system reports it. nil when it cannot be read.
    func read() async -> ModeReading?
    /// True when the call was accepted. The caller reads back to confirm the mode really changed.
    func write(_ on: Bool) async -> Bool
}

enum ModeBackends {
    static let all: [any ModeBackend] = [DarkModeBackend(), NightShiftBackend(), TrueToneBackend()]
}

/// What CBBlueLightClient reported, decoded inside the actor so the raw buffer never leaves it.
private struct BlueLightStatus: Sendable {
    enum Schedule: Equatable, Sendable { case off, sun, custom(from: Until, to: Until) }
    var enabled: Bool
    /// nil when the mode or a time in the status is out of range, so the layout is not what we think it is.
    var schedule: Schedule?
}

/// Owns the CoreBrightness client objects. They are not Sendable, so only this actor ever touches them. Selectors
/// are called through their IMP, typed per call, so nothing needs a header and a missing selector is nil, not a crash.
private actor CoreBrightness {
    static let shared = CoreBrightness()

    private typealias GetBool = @convention(c) (AnyObject, Selector) -> ObjCBool
    private typealias SetBool = @convention(c) (AnyObject, Selector, ObjCBool) -> ObjCBool
    private typealias GetStatus = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> ObjCBool

    // Loading the framework is what registers its classes; the handle itself is not needed afterwards.
    private static let loaded = dlopen(
        "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW) != nil

    private var blueLight: NSObject?
    private var trueTone: NSObject?

    // MARK: Night Shift

    /// CBBlueLightClient's status. nil when the client or the call is unavailable.
    func blueLightStatus() -> BlueLightStatus? {
        if blueLight == nil { blueLight = Self.make("CBBlueLightClient") }
        guard let client = blueLight else { return nil }
        let sel = sel_registerName("getBlueLightStatus:")
        guard let imp = Self.implementation(of: sel, on: client) else { return nil }
        // The status struct is not declared here: 64 zeroed bytes are more than it needs, and only a few are read.
        let status = UnsafeMutableRawPointer.allocate(byteCount: 64, alignment: 8)
        defer { status.deallocate() }
        memset(status, 0, 64)
        guard unsafeBitCast(imp, to: GetStatus.self)(client, sel, status).boolValue else { return nil }
        // Byte 0 is `active`, byte 1 is `enabled`. Switch to byte 0 if `enabled` turns out to mean "scheduled".
        return BlueLightStatus(enabled: status.load(fromByteOffset: 1, as: UInt8.self) != 0,
                               schedule: Self.schedule(in: status))
    }

    /// Little-endian, from the reverse-engineered CBBlueLightStatus: mode Int32 at 4 (0 none, 1 sunset to sunrise,
    /// 2 custom), then from hour/minute at 8/12 and to hour/minute at 16/20, all Int32.
    private static func schedule(in status: UnsafeMutableRawPointer) -> BlueLightStatus.Schedule? {
        func int32(_ offset: Int) -> Int { Int(status.loadUnaligned(fromByteOffset: offset, as: Int32.self)) }
        let mode = int32(4)
        let (fromHour, fromMinute, toHour, toMinute) = (int32(8), int32(12), int32(16), int32(20))
        guard (0...2).contains(mode), (0...23).contains(fromHour), (0...23).contains(toHour),
              (0...59).contains(fromMinute), (0...59).contains(toMinute) else { return nil }
        switch mode {
        case 0: return .off
        case 1: return .sun
        default: return .custom(from: .time(hour: fromHour, minute: fromMinute),
                                to: .time(hour: toHour, minute: toMinute))
        }
    }

    func setBlueLight(_ on: Bool) -> Bool {
        if blueLight == nil { blueLight = Self.make("CBBlueLightClient") }
        guard let client = blueLight else { return false }
        return Self.setBool(on, "setEnabled:", on: client)
    }

    // MARK: True Tone

    func trueToneSupported() -> Bool {
        if trueTone == nil { trueTone = Self.make("CBTrueToneClient") }
        guard let client = trueTone else { return false }
        return Self.getBool("supported", on: client) ?? false
    }

    func trueToneEnabled() -> Bool? {
        if trueTone == nil { trueTone = Self.make("CBTrueToneClient") }
        guard let client = trueTone else { return nil }
        return Self.getBool("enabled", on: client)
    }

    func setTrueTone(_ on: Bool) -> Bool {
        if trueTone == nil { trueTone = Self.make("CBTrueToneClient") }
        guard let client = trueTone else { return false }
        return Self.setBool(on, "setEnabled:", on: client)
    }

    // MARK: Plumbing

    private static func make(_ className: String) -> NSObject? {
        guard loaded else { return nil }
        return (NSClassFromString(className) as? NSObject.Type)?.init()
    }

    /// class_getMethodImplementation never returns nil: for an unknown selector it hands back the forwarding stub,
    /// which would raise. Asking the class first keeps that from happening.
    private static func implementation(of sel: Selector, on object: NSObject) -> IMP? {
        guard let cls = object_getClass(object), class_respondsToSelector(cls, sel) else { return nil }
        return class_getMethodImplementation(cls, sel)
    }

    private static func getBool(_ name: String, on object: NSObject) -> Bool? {
        let sel = sel_registerName(name)
        guard let imp = implementation(of: sel, on: object) else { return nil }
        return unsafeBitCast(imp, to: GetBool.self)(object, sel).boolValue
    }

    private static func setBool(_ on: Bool, _ name: String, on object: NSObject) -> Bool {
        let sel = sel_registerName(name)
        guard let imp = implementation(of: sel, on: object) else { return false }
        return unsafeBitCast(imp, to: SetBool.self)(object, sel, ObjCBool(on)).boolValue
    }
}

/// What this app changed by hand during this session. macOS words a manual change inside a schedule as "Until
/// Tomorrow". Kept in memory only.
private actor Overrides {
    static let shared = Overrides()

    private var nightShift = false
    private var darkMode = false

    func markNightShift() { nightShift = true }
    func markDarkMode() { darkMode = true }
    func nightShiftChanged() -> Bool { nightShift }
    func darkModeChanged() -> Bool { darkMode }
}

/// Dark Mode through SkyLight (private, loaded at runtime like the other private symbols), with System Events as a
/// fallback when the symbol is gone or the switch does not take. The switch runs under a WindowServer cross-fade, as
/// System Settings runs it, so the whole screen changes calmly instead of cutting.
struct DarkModeBackend: ModeBackend {
    var id: ModeID { .darkMode }

    private typealias Setter = @convention(c) (Bool) -> Void
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias NewTransition = @convention(c) (Int32, UnsafeRawPointer, UnsafeMutablePointer<Int32>) -> Int32
    /// The duration is a 32-bit float, not a double.
    private typealias InvokeTransition = @convention(c) (Int32, Int32, Float) -> Int32

    /// CGSTransitionSpec: 24 bytes, `type` 1 is a fade.
    private struct TransitionSpec {
        var unknown1: UInt32
        var type: Int32
        var option: Int32
        var wid: UInt32
        var backColour: UnsafeMutablePointer<Float>?
    }

    /// How long the screen is held after the switch so apps can redraw in the new appearance, then the fade itself.
    private static let redrawWait = Duration.milliseconds(200)
    private static let fadeDuration: Float = 0.4

    // The handle lives for the whole process and is only read, so sharing it is safe.
    nonisolated(unsafe) private static let handle = dlopen(
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)

    /// The fallback always exists, so the toggle is always offered.
    func isAvailable() async -> Bool { true }

    func read() async -> ModeReading? {
        let isOn = await MainActor.run {
            NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        // Only the automatic appearance has a time to name. When it is off, Dark Mode stays until changed by hand.
        guard UserDefaults.standard.bool(forKey: "AppleInterfaceStyleSwitchesAutomatically") else {
            return ModeReading(isOn: isOn, until: nil)
        }
        if await Overrides.shared.darkModeChanged() { return ModeReading(isOn: isOn, until: .tomorrow) }
        return ModeReading(isOn: isOn, until: isOn ? .sunrise : .sunset)
    }

    func write(_ on: Bool) async -> Bool {
        if let setter = Self.symbol("SLSSetAppearanceThemeLegacy", as: Setter.self) {
            await Self.set(on, using: setter)
            // The appearance lands asynchronously, so give it a moment before declaring the call a miss.
            for _ in 0..<3 {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return false }
                if await read()?.isOn == on {
                    await Overrides.shared.markDarkMode()
                    return true
                }
            }
        }
        let accepted = await Self.runAppleScript(on)
        if accepted { await Overrides.shared.markDarkMode() }
        return accepted
    }

    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: type)
    }

    /// Holds the screen, switches, waits for apps to redraw, then fades the hold away. A transition symbol that is
    /// missing or refuses leaves the bare, instant switch. Once the hold exists it is always released, so a cancelled
    /// wait cannot leave the screen frozen.
    private static func set(_ on: Bool, using setter: Setter) async {
        guard let connectionID = symbol("SLSMainConnectionID", as: MainConnection.self),
              let newTransition = symbol("SLSNewTransition", as: NewTransition.self),
              let invokeTransition = symbol("SLSInvokeTransition", as: InvokeTransition.self)
        else { return setter(on) }
        let connection = connectionID()
        var spec = TransitionSpec(unknown1: 0, type: 1, option: 0, wid: 0, backColour: nil)
        var transition: Int32 = 0
        let created = withUnsafePointer(to: &spec) { newTransition(connection, UnsafeRawPointer($0), &transition) }
        guard created == 0 else { return setter(on) }
        setter(on)
        try? await Task.sleep(for: redrawWait)
        // Invoke releases the transition itself; releasing it again returns an error.
        _ = invokeTransition(connection, transition, fadeDuration)
    }

    /// NSAppleScript must run on the main thread. It blocks there while macOS shows the automation prompt, once.
    @MainActor
    private static func runAppleScript(_ on: Bool) -> Bool {
        let source = "tell application \"System Events\" to tell appearance preferences to set dark mode to \(on)"
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        return error == nil
    }
}

/// Night Shift through CoreBrightness's CBBlueLightClient.
struct NightShiftBackend: ModeBackend {
    var id: ModeID { .nightShift }

    func isAvailable() async -> Bool { await CoreBrightness.shared.blueLightStatus() != nil }

    func read() async -> ModeReading? {
        guard let status = await CoreBrightness.shared.blueLightStatus() else { return nil }
        let natural: Until
        switch status.schedule {
        case nil, .off?: return ModeReading(isOn: status.enabled, until: nil)
        case .sun?: natural = status.enabled ? .sunrise : .sunset
        case .custom(let from, let to)?: natural = status.enabled ? to : from
        }
        let overridden = await Overrides.shared.nightShiftChanged()
        return ModeReading(isOn: status.enabled, until: overridden ? .tomorrow : natural)
    }

    func write(_ on: Bool) async -> Bool {
        // The schedule is read first: a change made inside one is what macOS calls "Until Tomorrow".
        let schedule = await CoreBrightness.shared.blueLightStatus()?.schedule
        let accepted = await CoreBrightness.shared.setBlueLight(on)
        if accepted, let schedule, schedule != .off { await Overrides.shared.markNightShift() }
        return accepted
    }
}

/// True Tone through CoreBrightness's CBTrueToneClient. Displays without the sensor report `supported` as false.
struct TrueToneBackend: ModeBackend {
    var id: ModeID { .trueTone }

    func isAvailable() async -> Bool { await CoreBrightness.shared.trueToneSupported() }
    func read() async -> ModeReading? {
        await CoreBrightness.shared.trueToneEnabled().map { ModeReading(isOn: $0, until: nil) }
    }
    func write(_ on: Bool) async -> Bool { await CoreBrightness.shared.setTrueTone(on) }
}
