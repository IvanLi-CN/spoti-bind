import AppKit
import SpotiBindCore
import XCTest
@testable import SpotiBind

@MainActor
final class AppStateTests: XCTestCase {
    func testLaunchFailureOffersFinderRecoveryAndRecordsTheTargetURL() {
        let revealer = RecordingApplicationRevealer()
        let state = AppState(
            applicationRevealer: revealer,
            environment: [
                "SPOTIBIND_UI_DEMO": "1",
                "SPOTIBIND_UI_DEMO_SCENE": UIDemoScenario.playerLaunchFailure.rawValue
            ]
        )

        XCTAssertEqual(state.statusAction, .revealInFinder(player: .sonora))
        XCTAssertEqual(state.statusActionTitle, "Show in Finder")

        state.performStatusAction()

        XCTAssertEqual(revealer.players, [.sonora])
        XCTAssertEqual(
            revealer.urls,
            [URL(fileURLWithPath: "/Demo/Applications/Sonora.app")]
        )
    }

    func testSuccessfulDeliveryClearsFailureForTheSameConfiguration() async {
        let dispatcher = StubPlayerDispatcher(results: [.launchFailed, .delivered])
        let state = makeState(dispatcher: dispatcher)

        state.dispatch(.playPause)
        await waitForDispatchToFinish(state)
        XCTAssertEqual(state.statusAction, .revealInFinder(player: .sonora))

        state.dispatch(.next)
        await waitForDispatchToFinish(state)
        XCTAssertNil(state.statusAction)
    }

    func testDispatchFailureKeepsTheLaunchFailureState() async {
        let dispatcher = StubPlayerDispatcher(results: [.launchFailed, .dispatchFailed])
        let state = makeState(dispatcher: dispatcher)

        state.dispatch(.playPause)
        await waitForDispatchToFinish(state)
        state.dispatch(.next)
        await waitForDispatchToFinish(state)

        XCTAssertEqual(state.playerLaunchFailure, .sonora)
        XCTAssertEqual(state.statusAction, .revealInFinder(player: .sonora))
    }

    func testChangingModeClearsFailure() async {
        let dispatcher = StubPlayerDispatcher(results: [.launchFailed])
        let state = makeState(dispatcher: dispatcher)

        state.dispatch(.playPause)
        await waitForDispatchToFinish(state)
        XCTAssertNotNil(state.statusAction)

        state.setPlayerMode(.off)

        XCTAssertEqual(state.statusTitle, "Forwarding disabled")
        XCTAssertNil(state.statusAction)
    }

    func testStaleFailureDoesNotReturnAfterModeChangesWhileDispatching() async {
        let dispatcher = StubPlayerDispatcher(
            results: [.launchFailed],
            delay: .milliseconds(50)
        )
        let state = makeState(dispatcher: dispatcher)

        state.dispatch(.playPause)
        state.setPlayerMode(.off)
        await waitForDispatchToFinish(state)

        XCTAssertEqual(state.statusTitle, "Forwarding disabled")
        XCTAssertNil(state.statusAction)
    }

    func testStaleFailureDoesNotReturnAfterModeLeavesAndReentersSamePlayer() async {
        let dispatcher = StubPlayerDispatcher(
            results: [.launchFailed],
            delay: .milliseconds(50)
        )
        let state = makeState(dispatcher: dispatcher)

        state.dispatch(.playPause)
        state.setPlayerMode(.off)
        state.setPlayerMode(.sonora)
        await waitForDispatchToFinish(state)

        XCTAssertNil(state.playerLaunchFailure)
        XCTAssertNil(state.dispatchFailure)
        XCTAssertNil(state.statusAction)
    }

    func testAutomaticModeDoesNotFallBackAfterLaunchFailure() async {
        let dispatcher = StubPlayerDispatcher(results: [.launchFailed])
        let defaults = UserDefaults(suiteName: "spoti-bind-automatic-failure-\(UUID().uuidString)")!
        defaults.set(PlayerMode.automatic.rawValue, forKey: "playerMode")
        let availability = AvailabilityBox(PlayerAvailabilitySnapshot([
            PlayerAvailability(
                player: .sonora,
                isInstalled: true,
                isRunning: false,
                canLaunch: true
            )
        ]))
        let state = AppState(
            defaults: defaults,
            playerDispatcher: dispatcher,
            availabilityProvider: { availability.snapshot },
            environment: [:],
            initialAvailability: availability.snapshot,
            initialAccessibilityTrusted: true,
            initialProbeHealthy: true
        )

        state.dispatch(.playPause)
        await waitForDispatchToFinish(state)
        XCTAssertEqual(state.statusAction, .revealInFinder(player: .sonora))

        availability.snapshot = PlayerAvailabilitySnapshot([
            PlayerAvailability(
                player: .spotify,
                isInstalled: true,
                isRunning: true,
                canLaunch: true
            )
        ])
        state.refreshStatus(promptForAccessibility: false)
        state.dispatch(.next)
        await waitForDispatchToFinish(state)

        let requests = await dispatcher.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.selection, .launch(.sonora))
        XCTAssertEqual(state.statusAction, .revealInFinder(player: .sonora))
    }

    private func makeState(dispatcher: any PlayerDispatching) -> AppState {
        let defaults = UserDefaults(suiteName: "spoti-bind-app-state-tests-\(UUID().uuidString)")!
        defaults.set(PlayerMode.sonora.rawValue, forKey: "playerMode")
        let availability = PlayerAvailabilitySnapshot([
            PlayerAvailability(
                player: .sonora,
                isInstalled: true,
                isRunning: false,
                canLaunch: true
            )
        ])
        let availabilityBox = AvailabilityBox(availability)
        return AppState(
            defaults: defaults,
            playerDispatcher: dispatcher,
            availabilityProvider: { availabilityBox.snapshot },
            environment: [:],
            initialAvailability: availability,
            initialAccessibilityTrusted: true,
            initialProbeHealthy: true
        )
    }

    private func waitForDispatchToFinish(_ state: AppState) async {
        while state.isDispatching {
            try? await Task.sleep(for: .milliseconds(1))
        }
    }
}

@MainActor
private final class RecordingApplicationRevealer: PlayerApplicationRevealing {
    private(set) var players: [SupportedPlayer] = []
    private(set) var urls: [URL?] = []

    func reveal(player: SupportedPlayer, applicationURL: URL?) {
        players.append(player)
        urls.append(applicationURL)
    }
}

private actor StubPlayerDispatcher: PlayerDispatching {
    private var results: [PlayerDispatchResult]
    private let delay: Duration
    private(set) var requests: [PlayerDispatchRequest] = []

    init(results: [PlayerDispatchResult], delay: Duration = .zero) {
        self.results = results
        self.delay = delay
    }

    func dispatch(
        _ key: MediaKey,
        request: PlayerDispatchRequest
    ) async -> PlayerDispatchResult {
        requests.append(request)
        if delay > .zero {
            try? await Task.sleep(for: delay)
        }
        return results.isEmpty ? .dispatchFailed : results.removeFirst()
    }
}

@MainActor
private final class AvailabilityBox {
    var snapshot: PlayerAvailabilitySnapshot

    init(_ snapshot: PlayerAvailabilitySnapshot) {
        self.snapshot = snapshot
    }
}
