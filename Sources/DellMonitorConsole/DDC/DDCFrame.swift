import Foundation

/// DDC/CI framing for MCCS Get and Set VCP. Pure functions; nothing here touches hardware.
enum DDCFrame {
    /// The brightness feature in MCCS. Dell shares the code, and so does every other vendor.
    static let brightness: UInt8 = 0x10

    /// Destination (0x37 << 1) xor source (0x51): the checksum of a host-to-display frame starts from this.
    private static let requestSeed: UInt8 = 0x6E ^ 0x51
    /// A display-to-host checksum starts from the virtual host address.
    private static let replySeed: UInt8 = 0x50

    /// The bytes after the source address, which the transport sends as the I2C data address.
    static func getVCP(_ code: UInt8) -> [UInt8] {
        sealed([0x82, 0x01, code])
    }

    static func setVCP(_ code: UInt8, value: UInt16) -> [UInt8] {
        sealed([0x84, 0x03, code, UInt8(value >> 8), UInt8(value & 0xFF)])
    }

    private static func sealed(_ body: [UInt8]) -> [UInt8] {
        body + [body.reduce(requestSeed, ^)]
    }

    enum Reply: Equatable {
        case value(current: Int, maximum: Int)
        /// The display understood the request and does not implement the feature.
        case unsupported
        /// A null message: the display answered, but has nothing to say to us.
        case nothing
        /// Stale, foreign (another client's answer), truncated or corrupt. Never trusted.
        case invalid
    }

    /// Validates a reply to `getVCP(code)`. The echoed code is checked because a display with two clients on its
    /// channel hands each of them the other's answers.
    static func parseGetVCP(_ bytes: [UInt8], code: UInt8) -> Reply {
        guard bytes.count >= 3, bytes[0] == 0x6E, bytes[1] & 0x80 != 0 else { return .invalid }
        let length = Int(bytes[1] & 0x7F)
        guard bytes.count >= length + 3 else { return .invalid }
        guard bytes[0..<(length + 2)].reduce(replySeed, ^) == bytes[length + 2] else { return .invalid }
        if length == 0 { return .nothing }
        guard length == 8, bytes[2] == 0x02, bytes[4] == code else { return .invalid }
        switch bytes[3] {
        case 0x00:
            let maximum = Int(bytes[6]) << 8 | Int(bytes[7])
            let current = Int(bytes[8]) << 8 | Int(bytes[9])
            return maximum > 0 ? .value(current: current, maximum: maximum) : .invalid
        case 0x01:
            return .unsupported
        default:
            return .invalid
        }
    }
}
