import XCTest
@testable import SpotiBindCore

final class MediaKeyEventRouterTests: XCTestCase {
    private let router = MediaKeyEventRouter()
    private let systemDefinedEventType: UInt32 = 14

    func testMouseAndKeyboardEventTypesAlwaysPassThrough() {
        let readiness = ForwardingReadiness(
            forwardingEnabled: true,
            accessibilityTrusted: true,
            targetUsable: true
        )

        for eventType: UInt32 in [1, 2, 5, 6, 10, 11, 12, 13] {
            XCTAssertEqual(
                router.decision(
                    eventType: eventType,
                    systemDefinedEventType: systemDefinedEventType,
                    data1: payload(keyCode: 16, state: 0x0a),
                    readiness: readiness
                ),
                .passThrough,
                "event type \(eventType) must not enter media-key routing"
            )
        }
    }

    func testOnlySystemDefinedMediaKeyEventsCanBeConsumed() {
        let readiness = ForwardingReadiness(
            forwardingEnabled: true,
            accessibilityTrusted: true,
            targetUsable: true
        )

        XCTAssertEqual(
            router.decision(
                eventType: systemDefinedEventType,
                systemDefinedEventType: systemDefinedEventType,
                data1: payload(keyCode: 16, state: 0x0a),
                readiness: readiness
            ),
            .route(.dispatch(.playPause))
        )
    }

    private func payload(keyCode: UInt32, state: UInt32) -> UInt32 {
        (keyCode << 16) | (state << 8)
    }
}
