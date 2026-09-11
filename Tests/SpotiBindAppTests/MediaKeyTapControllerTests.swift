import AppKit
import SpotiBindCore
import XCTest
@testable import SpotiBind

@MainActor
final class MediaKeyTapControllerTests: XCTestCase {
    func testMouseEventsPassThroughWithoutEnteringMediaKeyRouting() {
        let state = SpyMediaKeyTapState()
        let controller = MediaKeyTapController()
        controller.start(state: state)
        defer { controller.stop() }

        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: .zero,
            mouseButton: .left
        )!

        let result = controller.handle(event: event, type: .leftMouseDown)

        XCTAssertNotNil(result)
        XCTAssertTrue(state.dispatchedKeys.isEmpty)
    }

    func testUnknownSystemDefinedEventsPassThroughWithoutEnteringMediaKeyRouting() {
        let state = SpyMediaKeyTapState()
        let controller = MediaKeyTapController()
        controller.start(state: state)
        defer { controller.stop() }

        let event = CGEvent(source: nil)!
        let systemDefinedType = CGEventType(
            rawValue: UInt32(NSEvent.EventType.systemDefined.rawValue)
        )!
        let result = controller.handle(event: event, type: systemDefinedType)

        XCTAssertNotNil(result)
        XCTAssertTrue(state.dispatchedKeys.isEmpty)
    }
}

@MainActor
private final class SpyMediaKeyTapState: MediaKeyTapState {
    let readiness = ForwardingReadiness(
        forwardingEnabled: false,
        accessibilityTrusted: false,
        targetUsable: false
    )
    let accessibilityTrusted = false
    var dispatchedKeys: [MediaKey] = []

    func dispatch(_ key: MediaKey) {
        dispatchedKeys.append(key)
    }

    func setTapStatus(_ status: String) {}

    func setPlayerMode(_ mode: PlayerMode) {}
}
