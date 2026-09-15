import XCTest
@testable import SpotiBindCore

final class RoutingPolicyTests: XCTestCase {
    private let policy = RoutingPolicy()

    func testReadyDownDispatchesAndReleaseOrRepeatOnlyConsumes() {
        let readiness = readyState()

        XCTAssertEqual(
            policy.decision(
                for: MediaKeyEvent(key: .playPause, phase: .down),
                readiness: readiness
            ),
            .dispatch(.playPause)
        )
        XCTAssertEqual(
            policy.decision(
                for: MediaKeyEvent(key: .playPause, phase: .repeatEvent),
                readiness: readiness
            ),
            .consume
        )
        XCTAssertEqual(
            policy.decision(
                for: MediaKeyEvent(key: .playPause, phase: .up),
                readiness: readiness
            ),
            .consume
        )
    }

    func testEveryReadinessConditionIsRequiredBeforeConsumption() {
        let states = [
            ForwardingReadiness(forwardingEnabled: false, accessibilityTrusted: true, targetUsable: true),
            ForwardingReadiness(forwardingEnabled: true, accessibilityTrusted: false, targetUsable: true),
            ForwardingReadiness(forwardingEnabled: true, accessibilityTrusted: true, targetUsable: false)
        ]

        for state in states {
            XCTAssertFalse(state.isReady)
            XCTAssertEqual(
                policy.decision(
                    for: MediaKeyEvent(key: .next, phase: .down),
                    readiness: state
                ),
                .passThrough
            )
        }
    }

    func testReadyRouteIsIndependentOfForegroundPlayer() {
        XCTAssertEqual(
            policy.decision(
                for: MediaKeyEvent(key: .previous, phase: .down),
                readiness: readyState()
            ),
            .dispatch(.previous)
        )
    }

    private func readyState() -> ForwardingReadiness {
        ForwardingReadiness(
            forwardingEnabled: true,
            accessibilityTrusted: true,
            targetUsable: true
        )
    }
}
