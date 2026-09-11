import Foundation
import XCTest
@testable import SpotiBindCore

final class PlayerLaunchCoordinatorTests: XCTestCase {
    func testColdStartDispatchesTheFirstKeyOnceAfterThePlayerIsRunning() async {
        let runtime = RecordingPlayerRuntime(runningAfterChecks: 2)
        let coordinator = PlayerLaunchCoordinator(runtime: runtime, timeout: .seconds(1))
        let request = PlayerDispatchRequest(selection: .launch(.sonora))

        let result = await coordinator.dispatch(.next, request: request)

        XCTAssertTrue(result)
        let launches = await runtime.launches
        let dispatches = await runtime.dispatches
        XCTAssertEqual(launches, [.sonora])
        XCTAssertEqual(dispatches, [DispatchRecord(key: .next, player: .sonora)])
    }

    func testLaunchTimeoutDoesNotReplayTheKey() async {
        let runtime = RecordingPlayerRuntime(runningAfterChecks: Int.max)
        let coordinator = PlayerLaunchCoordinator(runtime: runtime, timeout: .milliseconds(20))
        let request = PlayerDispatchRequest(selection: .launch(.spotifly))

        let clock = ContinuousClock()
        let startedAt = clock.now
        let result = await coordinator.dispatch(.playPause, request: request)
        let elapsed = startedAt.duration(to: clock.now)
        let dispatches = await runtime.dispatches
        XCTAssertFalse(result)
        XCTAssertTrue(dispatches.isEmpty)
        XCTAssertLessThan(elapsed, .seconds(1))
    }

    func testLaunchOperationIsBoundedByTheTimeout() async {
        let runtime = RecordingPlayerRuntime(
            runningAfterChecks: 0,
            launchDelay: .seconds(1)
        )
        let coordinator = PlayerLaunchCoordinator(runtime: runtime, timeout: .milliseconds(20))
        let request = PlayerDispatchRequest(selection: .launch(.spotify))

        let clock = ContinuousClock()
        let startedAt = clock.now
        let result = await coordinator.dispatch(.playPause, request: request)
        let elapsed = startedAt.duration(to: clock.now)
        let dispatches = await runtime.dispatches

        XCTAssertFalse(result)
        XCTAssertLessThan(elapsed, .seconds(1))
        XCTAssertTrue(dispatches.isEmpty)
    }

    func testLaunchDispatchIsBoundedByTheTimeout() async {
        let runtime = RecordingPlayerRuntime(
            runningAfterChecks: 0,
            dispatchDelay: .seconds(1)
        )
        let coordinator = PlayerLaunchCoordinator(runtime: runtime, timeout: .milliseconds(20))
        let request = PlayerDispatchRequest(selection: .launch(.spotify))

        let clock = ContinuousClock()
        let startedAt = clock.now
        let result = await coordinator.dispatch(.playPause, request: request)
        let elapsed = startedAt.duration(to: clock.now)
        let dispatches = await runtime.dispatches

        XCTAssertFalse(result)
        XCTAssertLessThan(elapsed, .seconds(1))
        XCTAssertEqual(dispatches, [DispatchRecord(key: .playPause, player: .spotify)])
    }

    func testTimedOutLaunchDispatchDrainsBeforeTheNextGesture() async {
        let runtime = RecordingPlayerRuntime(
            runningAfterChecks: 0,
            dispatchDelay: .milliseconds(100),
            ignoresDispatchCancellation: true
        )
        let coordinator = PlayerLaunchCoordinator(runtime: runtime, timeout: .milliseconds(20))
        let launchRequest = PlayerDispatchRequest(selection: .launch(.spotify))
        let runningRequest = PlayerDispatchRequest(selection: .running(.spotify))

        let firstTask = Task {
            await coordinator.dispatch(.playPause, request: launchRequest)
        }
        let first = await firstTask.value
        let secondTask = Task {
            await coordinator.dispatch(.next, request: runningRequest)
        }
        let second = await secondTask.value

        let dispatches = await runtime.dispatches
        let maximumConcurrentDispatches = await runtime.maximumConcurrentDispatches
        XCTAssertFalse(first)
        XCTAssertTrue(second)
        XCTAssertEqual(dispatches.map(\.key), [.playPause, .next])
        XCTAssertEqual(maximumConcurrentDispatches, 1)
    }

    func testIndependentGesturesRemainSerialized() async {
        let runtime = RecordingPlayerRuntime(runningAfterChecks: 0, dispatchDelay: .milliseconds(10))
        let coordinator = PlayerLaunchCoordinator(runtime: runtime)
        let request = PlayerDispatchRequest(selection: .running(.sonora))

        let firstTask = Task {
            await coordinator.dispatch(.playPause, request: request)
        }
        await runtime.waitForDispatchCount(1)
        let secondTask = Task {
            await coordinator.dispatch(.next, request: request)
        }
        let first = await firstTask.value
        let second = await secondTask.value
        let dispatches = await runtime.dispatches
        let maximumConcurrentDispatches = await runtime.maximumConcurrentDispatches
        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertEqual(dispatches.map(\.key), [.playPause, .next])
        XCTAssertEqual(maximumConcurrentDispatches, 1)
    }
}

private actor RecordingPlayerRuntime: PlayerLaunchRuntime {
    private(set) var launches: [SupportedPlayer] = []
    private(set) var dispatches: [DispatchRecord] = []
    private(set) var maximumConcurrentDispatches = 0
    private var activeDispatches = 0
    private var runningChecks = 0
    private let runningAfterChecks: Int
    private let dispatchDelay: Duration
    private let launchDelay: Duration
    private let ignoresDispatchCancellation: Bool

    init(
        runningAfterChecks: Int,
        dispatchDelay: Duration = .zero,
        launchDelay: Duration = .zero,
        ignoresDispatchCancellation: Bool = false
    ) {
        self.runningAfterChecks = runningAfterChecks
        self.dispatchDelay = dispatchDelay
        self.launchDelay = launchDelay
        self.ignoresDispatchCancellation = ignoresDispatchCancellation
    }

    func launch(player: SupportedPlayer, applicationURL: URL?) async -> Bool {
        launches.append(player)
        if launchDelay > .zero {
            try? await Task.sleep(for: launchDelay)
        }
        return true
    }

    func isRunning(player: SupportedPlayer, applicationURL: URL?) async -> Bool {
        defer { runningChecks += 1 }
        return runningChecks >= runningAfterChecks
    }

    func dispatch(
        key: MediaKey,
        player: SupportedPlayer,
        executableURL: URL?,
        applicationURL: URL?
    ) async -> Bool {
        activeDispatches += 1
        maximumConcurrentDispatches = max(maximumConcurrentDispatches, activeDispatches)
        dispatches.append(DispatchRecord(key: key, player: player))
        if dispatchDelay > .zero {
            if ignoresDispatchCancellation {
                let delay = dispatchDelay
                await Task.detached {
                    try? await Task.sleep(for: delay)
                }.value
            } else {
                try? await Task.sleep(for: dispatchDelay)
            }
        }
        activeDispatches -= 1
        return true
    }

    func waitForDispatchCount(_ expected: Int) async {
        while dispatches.count < expected {
            await Task.yield()
        }
    }
}

private struct DispatchRecord: Equatable, Sendable {
    let key: MediaKey
    let player: SupportedPlayer
}
