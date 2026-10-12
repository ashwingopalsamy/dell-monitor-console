import Testing
@testable import DellMonitorConsole

@Suite struct DDCFrameTests {
    @Test func getBrightnessRequestMatchesTheWireBytes() {
        // Checksum is 0x6E ^ 0x51 ^ 82 01 10, the form every display accepts.
        #expect(DDCFrame.getVCP(0x10) == [0x82, 0x01, 0x10, 0xAC])
    }

    @Test func setBrightnessRequestMatchesTheWireBytes() {
        #expect(DDCFrame.setVCP(0x10, value: 50) == [0x84, 0x03, 0x10, 0x00, 0x32, 0x9A])
    }

    @Test func parsesAValidReply() {
        let reply: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x64, 0x00, 0x32, 0xF2, 0x00]
        #expect(DDCFrame.parseGetVCP(reply, code: 0x10) == .value(current: 50, maximum: 100))
    }

    @Test func rejectsAnotherClientsAnswer() {
        // A well-formed reply for VCP F6, which nobody here asked for.
        let reply: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0xF6, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x42, 0x00]
        #expect(DDCFrame.parseGetVCP(reply, code: 0x10) == .invalid)
    }

    @Test func recognisesTheNullMessage() {
        let reply: [UInt8] = [0x6E, 0x80, 0xBE, 0x3A, 0xB5, 0xFF, 0x9D, 0x37, 0xB3, 0x63, 0x23, 0x6E]
        #expect(DDCFrame.parseGetVCP(reply, code: 0x10) == .nothing)
    }

    @Test func rejectsACorruptChecksum() {
        let reply: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x64, 0x00, 0x32, 0xF3, 0x00]
        #expect(DDCFrame.parseGetVCP(reply, code: 0x10) == .invalid)
    }

    @Test func rejectsStaleBufferNoise() {
        let reply: [UInt8] = [0x2F, 0x9A, 0x2D, 0x3A, 0xB5, 0xFF, 0x9D, 0x37, 0xB3, 0x63, 0x23, 0x6E]
        #expect(DDCFrame.parseGetVCP(reply, code: 0x10) == .invalid)
    }
}
