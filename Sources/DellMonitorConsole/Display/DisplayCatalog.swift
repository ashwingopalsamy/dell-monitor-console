import AppKit
import CoreGraphics

/// One display macOS is driving right now, with its DDC channel when it has one.
struct DisplayInfo: Sendable, Identifiable {
    /// The display's CoreGraphics UUID: stable across reconnects, and distinct for two identical monitors.
    let id: String
    let cgID: CGDirectDisplayID
    let name: String
    let isBuiltIn: Bool
    let service: AVService?
}

enum DisplayCatalog {
    @MainActor
    static func current() -> [DisplayInfo] {
        var unclaimed = AVRegistry.candidates()
        var result: [DisplayInfo] = []

        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            else { continue }
            let cgID = CGDirectDisplayID(number.uint32Value)
            let builtIn = CGDisplayIsBuiltin(cgID) != 0

            var service: AVService?
            if !builtIn, let index = bestMatch(for: cgID, in: unclaimed) {
                service = unclaimed.remove(at: index).service
            }
            result.append(DisplayInfo(
                id: identifier(for: cgID),
                cgID: cgID,
                name: screen.localizedName,
                isBuiltIn: builtIn,
                service: service
            ))
        }
        return result
    }

    private static func identifier(for display: CGDirectDisplayID) -> String {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(display)?.takeRetainedValue(),
              let string = CFUUIDCreateString(nil, uuid) as String?
        else { return "display-\(display)" }
        return string
    }

    /// Vendor and product narrow it down; the serial breaks a tie between identical monitors. When the registry
    /// cannot tell two identical monitors apart, they are paired in order, which is correct for a single pair.
    private static func bestMatch(for display: CGDirectDisplayID, in candidates: [AVCandidate]) -> Int? {
        let vendor = CGDisplayVendorNumber(display)
        let model = CGDisplayModelNumber(display)
        let serial = CGDisplaySerialNumber(display)
        let sameModel = candidates.indices.filter {
            candidates[$0].vendor == vendor && candidates[$0].product == model
        }
        if let exact = sameModel.first(where: { serial != 0 && candidates[$0].serial == serial }) { return exact }
        return sameModel.first
    }
}
