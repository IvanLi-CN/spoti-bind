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

    func testAuxiliaryMouseSystemDefinedEventsPassThroughWithoutDispatching() {
        let state = SpyMediaKeyTapState()
        let controller = MediaKeyTapController()
        controller.start(state: state)
        defer { controller.stop() }

        state.readiness = ForwardingReadiness(
            forwardingEnabled: true,
            accessibilityTrusted: true,
            targetUsable: true
        )
        state.accessibilityTrusted = true

        let data1 = (UInt32(16) << 16) | (UInt32(0x0a) << 8)
        let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 7,
            data1: Int(data1),
            data2: 0
        )!.cgEvent!
        let systemDefinedType = CGEventType(
            rawValue: UInt32(NSEvent.EventType.systemDefined.rawValue)
        )!

        let result = controller.handle(event: event, type: systemDefinedType)

        XCTAssertNotNil(result)
        XCTAssertTrue(state.dispatchedKeys.isEmpty)
    }

    func testMediaKeySystemDefinedSubtypeDispatchesSupportedPress() {
        let state = SpyMediaKeyTapState()
        let controller = MediaKeyTapController()
        controller.start(state: state)
        defer { controller.stop() }

        state.readiness = ForwardingReadiness(
            forwardingEnabled: true,
            accessibilityTrusted: true,
            targetUsable: true
        )
        state.accessibilityTrusted = true

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

        XCTAssertNil(result)
        XCTAssertEqual(state.dispatchedKeys, [.playPause])
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
        state.accessibilityTrusted = false

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
    var accessibilityTrusted = false
    var dispatchedKeys: [MediaKey] = []

    func dispatch(_ key: MediaKey) {
        dispatchedKeys.append(key)
    }

    func setTapStatus(_ status: String) {}

    func setPlayerMode(_ mode: PlayerMode) {}
}
