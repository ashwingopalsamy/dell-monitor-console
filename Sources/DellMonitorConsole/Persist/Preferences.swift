import Foundation
import ServiceManagement

/// The few things worth keeping between launches. Plain `UserDefaults`; nothing here is sensitive.
enum Preferences {
    private static let softwareKey = "softwareLevels"
    private static let lastUsedKey = "lastUsedDisplay"

    static func softwareLevel(for id: String) -> Int? {
        (UserDefaults.standard.dictionary(forKey: softwareKey) as? [String: Int])?[id]
    }

    static func setSoftwareLevel(_ level: Int, for id: String) {
        var levels = (UserDefaults.standard.dictionary(forKey: softwareKey) as? [String: Int]) ?? [:]
        levels[id] = level
        UserDefaults.standard.set(levels, forKey: softwareKey)
    }

    static var lastUsedDisplay: String? {
        get { UserDefaults.standard.string(forKey: lastUsedKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastUsedKey) }
    }
}

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
