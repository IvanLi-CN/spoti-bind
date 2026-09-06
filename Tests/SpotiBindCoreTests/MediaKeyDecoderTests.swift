import XCTest
@testable import SpotiBindCore

final class MediaKeyDecoderTests: XCTestCase {
    private let decoder = SystemDefinedMediaKeyDecoder()

    func testDecodesPlayPauseDownAndUp() {
        XCTAssertEqual(
            decoder.decode(data1: payload(keyCode: 16, state: 0x0a)),
            MediaKeyEvent(key: .playPause, phase: .down)
        )
        XCTAssertEqual(
            decoder.decode(data1: payload(keyCode: 16, state: 0x0b)),
            MediaKeyEvent(key: .playPause, phase: .up)
        )
    }

    func testDecodesNextAndPreviousRepeat() {
        XCTAssertEqual(
            decoder.decode(data1: payload(keyCode: 17, state: 0x0a, isRepeat: true)),
            MediaKeyEvent(key: .next, phase: .repeatEvent)
        )
        XCTAssertEqual(
            decoder.decode(data1: payload(keyCode: 18, state: 0x0a)),
            MediaKeyEvent(key: .previous, phase: .down)
        )
    }

    func testUnknownKeyAndStatePassThroughToCaller() {
        XCTAssertNil(decoder.decode(data1: payload(keyCode: 19, state: 0x0a)))
        XCTAssertNil(decoder.decode(data1: payload(keyCode: 16, state: 0x0c)))
    }

    private func payload(keyCode: UInt32, state: UInt32, isRepeat: Bool = false) -> UInt32 {
        let flags = (state << 8) | (isRepeat ? 1 : 0)
        return (keyCode << 16) | flags
    }
}
