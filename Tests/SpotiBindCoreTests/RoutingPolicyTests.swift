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
            ForwardingReadiness(forwardingEnabled: false, accessibilityTrusted: true, targetUsable: true, probeHealthy: true),
            ForwardingReadiness(forwardingEnabled: true, accessibilityTrusted: false, targetUsable: true, probeHealthy: true),
            ForwardingReadiness(forwardingEnabled: true, accessibilityTrusted: true, targetUsable: false, probeHealthy: true),
            ForwardingReadiness(forwardingEnabled: true, accessibilityTrusted: true, targetUsable: true, probeHealthy: false)
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

    func testTapFailureRetriesOnceThenDisablesWithinWindow() {
        var tracker = TapFailureTracker(retryWindow: 10)
        let first = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(tracker.recordFailure(at: first), .retryOnce)
        XCTAssertEqual(
            tracker.recordFailure(at: first.addingTimeInterval(10)),
            .disableForwarding
        )
        XCTAssertEqual(
            tracker.recordFailure(at: first.addingTimeInterval(20.1)),
            .retryOnce
        )
    }

    func testSuccessfulTapResetStartsNewRetryWindow() {
        var tracker = TapFailureTracker()
        let first = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(tracker.recordFailure(at: first), .retryOnce)
        tracker.reset()
        XCTAssertEqual(
            tracker.recordFailure(at: first.addingTimeInterval(1)),
            .retryOnce
        )
    }

    private func readyState() -> ForwardingReadiness {
        ForwardingReadiness(
            forwardingEnabled: true,
            accessibilityTrusted: true,
            targetUsable: true,
            probeHealthy: true
        )
    }
}
