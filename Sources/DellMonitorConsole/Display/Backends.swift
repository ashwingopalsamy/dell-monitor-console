import CoreGraphics
import Foundation

enum BackendKind: Sendable {
    /// Real backlight control over DDC/CI.
    case ddc
    /// The built-in panel, through macOS.
    case builtIn
    /// A gamma-table dim for a display that does not answer DDC/CI. It lowers the picture, not the backlight.
    case software
}

protocol BrightnessBackend: Sendable {
    var kind: BackendKind { get }
    /// Time to leave between consecutive writes, so a fast drag does not queue behind a slow monitor.
    var writeSpacing: Duration { get }
    /// The level the display reports, 0...100. nil when it cannot be read.
    func read() async -> Int?
    /// True when the display accepted the write.
    func write(_ percent: Int) async -> Bool
}

struct DDCBackend: BrightnessBackend {
    let display: DDCDisplay
    var kind: BackendKind { .ddc }
    var writeSpacing: Duration { .milliseconds(60) }

    func read() async -> Int? { await display.readBrightness() }
    func write(_ percent: Int) async -> Bool { await display.writeBrightness(percent: percent) }
}

/// The built-in panel through DisplayServices (private, loaded at runtime like the DDC symbols).
struct BuiltInBackend: BrightnessBackend {
    let cgID: CGDirectDisplayID
    var kind: BackendKind { .builtIn }
    var writeSpacing: Duration { .milliseconds(16) }

    private typealias Getter = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias Setter = @convention(c) (CGDirectDisplayID, Float) -> Int32

    // The handle lives for the whole process and is only read, so sharing it is safe.
    nonisolated(unsafe) private static let handle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)

    func read() async -> Int? {
        guard let handle = Self.handle, let symbol = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        var level: Float = 0
        guard unsafeBitCast(symbol, to: Getter.self)(cgID, &level) == 0 else { return nil }
        return Int((level * 100).rounded())
    }

    func write(_ percent: Int) async -> Bool {
        guard let handle = Self.handle, let symbol = dlsym(handle, "DisplayServicesSetBrightness") else { return false }
        return unsafeBitCast(symbol, to: Setter.self)(cgID, Float(percent) / 100) == 0
    }

    static var isAvailable: Bool {
        guard let handle else { return false }
        return dlsym(handle, "DisplayServicesGetBrightness") != nil
    }
}

/// Dims through the display's gamma table, which every display accepts. macOS restores the table when the process
/// exits, so the dim lasts exactly as long as the app runs.
struct SoftwareBackend: BrightnessBackend {
    /// Never fully dark: a black screen cannot be undone by looking at it.
    static let floor = 10

    let cgID: CGDirectDisplayID
    let id: String
    var kind: BackendKind { .software }
    var writeSpacing: Duration { .zero }

    func read() async -> Int? { Preferences.softwareLevel(for: id) ?? 100 }

    func write(_ percent: Int) async -> Bool {
        let level = min(100, max(Self.floor, percent))
        let factor = CGGammaValue(level) / 100
        let applied = CGSetDisplayTransferByFormula(cgID, 0, factor, 1, 0, factor, 1, 0, factor, 1) == .success
        if applied { Preferences.setSoftwareLevel(level, for: id) }
        return applied
    }

    static func restoreAll() {
        CGDisplayRestoreColorSyncSettings()
    }
}
