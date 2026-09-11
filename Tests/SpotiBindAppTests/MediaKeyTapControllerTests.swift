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

    func testRevokedAccessibilityPassesSupportedMediaKeysThrough() {
        let state = SpyMediaKeyTapState()
        let controller = MediaKeyTapController()
        controller.start(state: state)
        defer { controller.stop() }

        state.readiness = ForwardingReadiness(
            forwardingEnabled: true,
            accessibilityTrusted: true,
            targetUsable: true
        )
        state.eventAccessibilityTrusted = false

        let data1 = (UInt32(16) << 16) | (UInt32(0x0a) << 8)
        let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: Int(data1),
            data2: 0
        )!.cgEvent!
        let systemDefinedType = CGEventType(
            rawValue: UInt32(NSEvent.EventType.systemDefined.rawValue)
        )!

        let result = controller.handle(event: event, type: systemDefinedType)

        XCTAssertNotNil(result)
        XCTAssertEqual(state.eventTrustChecks, 1)
        XCTAssertTrue(state.dispatchedKeys.isEmpty)
    }
}

@MainActor
private final class SpyMediaKeyTapState: MediaKeyTapState {
    var readiness = ForwardingReadiness(
        forwardingEnabled: false,
        accessibilityTrusted: false,
        targetUsable: false
    )
    let accessibilityTrusted = false
    var dispatchedKeys: [MediaKey] = []
    var eventAccessibilityTrusted = true
    var eventTrustChecks = 0

    func accessibilityTrustedForEvent() -> Bool {
        eventTrustChecks += 1
        return eventAccessibilityTrusted
    }

    func dispatch(_ key: MediaKey) {
        dispatchedKeys.append(key)
    }

    func setTapStatus(_ status: String) {}

    func setPlayerMode(_ mode: PlayerMode) {}
}
