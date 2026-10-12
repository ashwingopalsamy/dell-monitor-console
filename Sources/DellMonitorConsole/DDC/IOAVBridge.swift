import Foundation
import IOKit

/// The private IOKit entry points DDC/CI needs on Apple silicon. They are resolved at runtime and only here, so a
/// macOS that drops one leaves the app running on software dimming instead of failing to launch.
struct IOAVBridge: Sendable {
    typealias Create = @convention(c) (CFAllocator?, io_service_t) -> UnsafeMutableRawPointer?
    typealias Transfer = @convention(c) (UnsafeMutableRawPointer, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> IOReturn

    let create: Create
    let read: Transfer
    let write: Transfer

    static let shared: IOAVBridge? = {
        guard let handle = dlopen(nil, RTLD_NOW),
              let create = dlsym(handle, "IOAVServiceCreateWithService"),
              let read = dlsym(handle, "IOAVServiceReadI2C"),
              let write = dlsym(handle, "IOAVServiceWriteI2C")
        else { return nil }
        return IOAVBridge(
            create: unsafeBitCast(create, to: Create.self),
            read: unsafeBitCast(read, to: Transfer.self),
            write: unsafeBitCast(write, to: Transfer.self)
        )
    }()
}

/// One display's DDC/CI channel. Transfers are blocking I2C transactions, so a service belongs to one serial
/// context (`DDCDisplay`); `@unchecked Sendable` only lets it be handed to that context.
final class AVService: @unchecked Sendable {
    private static let chip: UInt32 = 0x37
    /// The host's source address, which the transport sends as the first data byte.
    private static let sourceAddress: UInt32 = 0x51

    private let reference: UnsafeMutableRawPointer
    private let bridge: IOAVBridge

    init?(entry: io_service_t) {
        guard let bridge = IOAVBridge.shared, let reference = bridge.create(kCFAllocatorDefault, entry) else {
            return nil
        }
        self.bridge = bridge
        self.reference = reference
    }

    deinit {
        // IOAVServiceCreateWithService follows the Create rule.
        Unmanaged<AnyObject>.fromOpaque(reference).release()
    }

    func send(_ frame: [UInt8]) -> Bool {
        var frame = frame
        return frame.withUnsafeMutableBytes {
            bridge.write(reference, Self.chip, Self.sourceAddress, $0.baseAddress!, UInt32($0.count)) == KERN_SUCCESS
        }
    }

    func receive(count: Int) -> [UInt8]? {
        var buffer = [UInt8](repeating: 0, count: count)
        let status = buffer.withUnsafeMutableBytes {
            bridge.read(reference, Self.chip, 0, $0.baseAddress!, UInt32(count))
        }
        return status == KERN_SUCCESS ? buffer : nil
    }
}

/// Serialises every transaction for one display on its own queue. Waiting between a request and its reply is a
/// plain sleep on that queue, which keeps the pair atomic (an `await` would let another request interleave) and
/// keeps blocking I/O off the cooperative pool.
actor DDCDisplay {
    private let queue = DispatchSerialQueue(label: "dell-monitor-console.ddc")
    private let service: AVService
    private var maximum = 100

    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    init(service: AVService) {
        self.service = service
    }

    /// Brightness as 0...100, or nil when the display never gives a validated answer.
    ///
    /// Each request goes out twice, 40 ms apart, before the reply is read. Some displays (the U2723QE is one)
    /// swallow the first request after being idle and answer only the second; a read in between, or a single
    /// request, only ever returns a null message. A display that answers both returns the same answer twice.
    /// Later attempts wait longer, because a display that is busy answers late rather than not at all.
    func readBrightness(attempts: Int = 4) -> Int? {
        let request = DDCFrame.getVCP(DDCFrame.brightness)
        for attempt in 0..<attempts {
            let first = service.send(request)
            usleep(Self.pairGap)
            let second = service.send(request)
            guard first || second else {
                usleep(Self.pairGap)
                continue
            }
            usleep(UInt32(100_000 + 50_000 * attempt))
            guard let bytes = service.receive(count: 12) else { continue }
            switch DDCFrame.parseGetVCP(bytes, code: DDCFrame.brightness) {
            case .value(let current, let maximum):
                self.maximum = maximum
                return min(100, (current * 100 + maximum / 2) / maximum)
            case .unsupported:
                return nil
            case .nothing, .invalid:
                continue
            }
        }
        return nil
    }

    /// Sent twice for the same reason a read is: the first command after idle can be swallowed. Setting the same
    /// level again is harmless.
    func writeBrightness(percent: Int) -> Bool {
        let clamped = min(100, max(0, percent))
        let raw = (clamped * maximum + 50) / 100
        let frame = DDCFrame.setVCP(DDCFrame.brightness, value: UInt16(raw))
        let first = service.send(frame)
        usleep(Self.pairGap)
        let second = service.send(frame)
        return first || second
    }

    /// DDC/CI asks for at least 40 ms between commands.
    private static let pairGap: UInt32 = 40_000
}
