import Foundation
import IOKit

/// An external display's DDC channel together with the identity the registry gives it.
struct AVCandidate: Sendable {
    let name: String?
    let vendor: UInt32?
    let product: UInt32?
    let serial: UInt32?
    let service: AVService
}

/// Finds the DDC channels of the external displays. The channel (`DCPAVServiceProxy`) and the display's identity
/// live in different registry nodes that share only a `dispextN` name, so the two are joined on that name.
enum AVRegistry {
    static func candidates() -> [AVCandidate] {
        var iterator: io_iterator_t = 0
        guard IORegistryCreateIterator(
            kIOMainPortDefault, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator
        ) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var identities: [String: [String: Any]] = [:]
        var proxies: [(port: String, service: AVService)] = []

        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            let name = registryName(entry)
            if name.hasPrefix("dispext"), !name.contains(":") {
                let attributes = IORegistryEntrySearchCFProperty(
                    entry, kIOServicePlane, "DisplayAttributes" as CFString, kCFAllocatorDefault,
                    IOOptionBits(kIORegistryIterateRecursively)) as? [String: Any]
                if let product = attributes?["ProductAttributes"] as? [String: Any] {
                    identities[name] = product
                }
            } else if className(entry) == "DCPAVServiceProxy",
                      property(entry, "Location") as? String == "External",
                      let port = portName(of: entry),
                      let service = AVService(entry: entry) {
                proxies.append((port, service))
            }
        }

        return proxies.map { port, service in
            let identity = identities[port]
            return AVCandidate(
                name: identity?["ProductName"] as? String,
                vendor: (identity?["LegacyManufacturerID"] as? NSNumber)?.uint32Value,
                product: (identity?["ProductID"] as? NSNumber)?.uint32Value,
                serial: (identity?["SerialNumber"] as? NSNumber)?.uint32Value,
                service: service
            )
        }
    }

    // MARK: - Registry helpers

    private static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    private static func className(_ entry: io_registry_entry_t) -> String {
        guard let name = IOObjectCopyClass(entry) else { return "" }
        return name.takeRetainedValue() as String
    }

    private static func registryName(_ entry: io_registry_entry_t) -> String {
        var name = [CChar](repeating: 0, count: 128)
        guard IORegistryEntryGetName(entry, &name) == KERN_SUCCESS else { return "" }
        return string(from: name)
    }

    /// `dispext1:dcpav-service-epic:0` names the node the channel hangs off; the part before the first colon is the
    /// port the identity node shares.
    private static func portName(of entry: io_registry_entry_t) -> String? {
        var path = [CChar](repeating: 0, count: 512)
        guard IORegistryEntryGetPath(entry, kIOServicePlane, &path) == KERN_SUCCESS else { return nil }
        let component = string(from: path).split(separator: "/").first { $0.hasPrefix("dispext") }
        return component.map { String($0.split(separator: ":")[0]) }
    }

    private static func string(from buffer: [CChar]) -> String {
        String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
