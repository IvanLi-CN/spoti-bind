import Foundation
import XCTest
@testable import SpotiBindCore

final class PlayerLaunchCoordinatorTests: XCTestCase {
    func testLaunchFailureReturnsStructuredResultWithoutDispatching() async {
        let runtime = RecordingPlayerRuntime(runningAfterChecks: 0, launchResult: false)
        let coordinator = PlayerLaunchCoordinator(runtime: runtime, timeout: .seconds(1))

        let result = await coordinator.dispatch(
            .playPause,
            request: PlayerDispatchRequest(selection: .launch(.sonora))
        )

        XCTAssertEqual(result, .launchFailed)
        let dispatches = await runtime.dispatches
        XCTAssertTrue(dispatches.isEmpty)
    }

    func testQueuedLaunchContinuesAfterImmediatePreviousDispatchFailure() async {
        let runtime = FailFirstDispatchPlayerRuntime()
        let coordinator = PlayerLaunchCoordinator(runtime: runtime, timeout: .seconds(1))
        let runningRequest = PlayerDispatchRequest(selection: .running(.spotify))
        let launchRequest = PlayerDispatchRequest(selection: .launch(.spotify))

        let first = await coordinator.dispatch(.playPause, request: runningRequest)
        let second = await coordinator.dispatch(.next, request: launchRequest)

        XCTAssertEqual(first, .dispatchFailed)
        XCTAssertEqual(second, .delivered)
        let launches = await runtime.launches
        let dispatches = await runtime.dispatches
        XCTAssertEqual(launches, [.spotify])
        XCTAssertEqual(dispatches.map(\.key), [.playPause, .next])
    }

    func testDispatchFailureReturnsStructuredResult() async {
        let runtime = RecordingPlayerRuntime(runningAfterChecks: 0, dispatchResult: false)
        let coordinator = PlayerLaunchCoordinator(runtime: runtime)

        let result = await coordinator.dispatch(
            .next,
            request: PlayerDispatchRequest(selection: .running(.sonora))
        )

        XCTAssertEqual(result, .dispatchFailed)
    }

    func testCancellationInsensitiveDispatchReturnsAtTheDeadlineAndDoesNotOverlap() async {
        let runtime = HangingDispatchPlayerRuntime()
        let coordinator = PlayerLaunchCoordinator(runtime: runtime, timeout: .milliseconds(20))
        let request = PlayerDispatchRequest(selection: .running(.spotify))

        let clock = ContinuousClock()
        let startedAt = clock.now
        let result = await coordinator.dispatch(.playPause, request: request)
        let elapsed = startedAt.duration(to: clock.now)

        XCTAssertEqual(result, .dispatchTimedOut)
        XCTAssertLessThan(elapsed, .seconds(1))
        let dispatchCount = await runtime.dispatchCount
        XCTAssertEqual(dispatchCount, 1)

        let second = await coordinator.dispatch(
            .next,
            request: PlayerDispatchRequest(selection: .running(.spotify))
        )
        XCTAssertEqual(second, .dispatchTimedOut)
        let third = await coordinator.dispatch(
            .previous,
            request: PlayerDispatchRequest(selection: .running(.spotify))
        )
        XCTAssertEqual(third, .dispatchTimedOut)
        let finalDispatchCount = await runtime.dispatchCount
        XCTAssertEqual(finalDispatchCount, 1)

        await runtime.finishDispatch()
    }

    func testColdStartDispatchesTheFirstKeyOnceAfterThePlayerIsRunning() async {
        let runtime = RecordingPlayerRuntime(runningAfterChecks: 2)
        let coordinator = PlayerLaunchCoordinator(runtime: runtime, timeout: .seconds(1))
        let request = PlayerDispatchRequest(selection: .launch(.sonora))

        let result = await coordinator.dispatch(.next, request: request)

        XCTAssertEqual(result, .delivered)
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
        XCTAssertEqual(result, .targetNotReady)
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

        XCTAssertEqual(result, .launchTimedOut)
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

        XCTAssertEqual(result, .dispatchTimedOut)
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
        let thirdTask = Task {
            await coordinator.dispatch(.previous, request: runningRequest)
        }
        let third = await thirdTask.value

        let inFlightDispatches = await runtime.dispatches
        let inFlightMaximumConcurrentDispatches = await runtime.maximumConcurrentDispatches
        XCTAssertEqual(first, .dispatchTimedOut)
        XCTAssertEqual(second, .dispatchTimedOut)
        XCTAssertEqual(third, .dispatchTimedOut)
        XCTAssertEqual(inFlightDispatches.map(\.key), [.playPause])
        XCTAssertEqual(inFlightMaximumConcurrentDispatches, 1)

        try? await Task.sleep(for: .milliseconds(120))
        let dispatches = await runtime.dispatches
        let maximumConcurrentDispatches = await runtime.maximumConcurrentDispatches
        XCTAssertEqual(dispatches.map(\.key), [.playPause])
        XCTAssertEqual(maximumConcurrentDispatches, 1)
    }

    func testTimedOutLaunchDispatchKeepsTheQueueTailUntilTheSideEffectFinishes() async {
        let runtime = RecordingPlayerRuntime(
            runningAfterChecks: 0,
            dispatchDelay: .milliseconds(100),
            ignoresDispatchCancellation: true
        )
        let coordinator = PlayerLaunchCoordinator(runtime: runtime, timeout: .milliseconds(20))
        let launchRequest = PlayerDispatchRequest(selection: .launch(.spotify))
        let runningRequest = PlayerDispatchRequest(selection: .running(.spotify))

        let first = await coordinator.dispatch(.playPause, request: launchRequest)
        let second = await coordinator.dispatch(.next, request: runningRequest)
        let third = await coordinator.dispatch(.previous, request: runningRequest)

        let inFlightDispatches = await runtime.dispatches
        let inFlightMaximumConcurrentDispatches = await runtime.maximumConcurrentDispatches
        XCTAssertEqual(first, .dispatchTimedOut)
        XCTAssertEqual(second, .dispatchTimedOut)
        XCTAssertEqual(third, .dispatchTimedOut)
        XCTAssertEqual(inFlightDispatches.map(\.key), [.playPause])
        XCTAssertEqual(inFlightMaximumConcurrentDispatches, 1)

        try? await Task.sleep(for: .milliseconds(120))
        let dispatches = await runtime.dispatches
        let maximumConcurrentDispatches = await runtime.maximumConcurrentDispatches
        XCTAssertEqual(dispatches.map(\.key), [.playPause])
        XCTAssertEqual(maximumConcurrentDispatches, 1)
    }

    func testTimedOutLaunchKeepsTheQueueTailUntilLaunchFinishes() async {
        let runtime = RecordingPlayerRuntime(
            runningAfterChecks: 0,
            launchDelay: .milliseconds(100),
            ignoresLaunchCancellation: true
        )
        let coordinator = PlayerLaunchCoordinator(runtime: runtime, timeout: .milliseconds(20))
        let launchRequest = PlayerDispatchRequest(selection: .launch(.spotify))
        let runningRequest = PlayerDispatchRequest(selection: .running(.spotify))

        let first = await coordinator.dispatch(.playPause, request: launchRequest)
        let second = await coordinator.dispatch(.next, request: runningRequest)

        let inFlightDispatches = await runtime.dispatches
        XCTAssertEqual(first, .launchTimedOut)
        XCTAssertEqual(second, .launchBlocked)
        XCTAssertTrue(inFlightDispatches.isEmpty)

        try? await Task.sleep(for: .milliseconds(120))
        let third = await coordinator.dispatch(.previous, request: runningRequest)
        XCTAssertEqual(third, .delivered)
        let dispatches = await runtime.dispatches
        XCTAssertEqual(dispatches.map(\.key), [.previous])
    }

    func testQueuedLaunchKeepsTheQueueTailAndBarrierUntilPreviousDispatchFinishes() async {
        let runtime = HangingDispatchPlayerRuntime()
        let coordinator = PlayerLaunchCoordinator(runtime: runtime, timeout: .milliseconds(20))
        let runningRequest = PlayerDispatchRequest(selection: .running(.spotify))
        let launchRequest = PlayerDispatchRequest(selection: .launch(.spotify))

        let firstTask = Task {
            await coordinator.dispatch(.playPause, request: runningRequest)
        }
        await runtime.waitForDispatchCount(1)
        let first = await firstTask.value
        let second = await coordinator.dispatch(.next, request: launchRequest)
        let third = await coordinator.dispatch(.previous, request: runningRequest)

        XCTAssertEqual(first, .dispatchTimedOut)
        XCTAssertEqual(second, .launchTimedOut)
        XCTAssertEqual(third, .launchBlocked)
        let inFlightDispatchCount = await runtime.dispatchCount
        XCTAssertEqual(inFlightDispatchCount, 1)

        await runtime.finishDispatch()
        try? await Task.sleep(for: .milliseconds(40))

        let fourth = await coordinator.dispatch(.previous, request: runningRequest)
        XCTAssertEqual(fourth, .delivered)
        let finalDispatchCount = await runtime.dispatchCount
        XCTAssertEqual(finalDispatchCount, 2)
    }

    func testTimedOutLaunchDrainsBeforeTheNextGesture() async {
        let runtime = RecordingPlayerRuntime(
            runningAfterChecks: 0,
            launchDelay: .milliseconds(100),
            ignoresLaunchCancellation: true
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

        try? await Task.sleep(for: .milliseconds(120))
        let third = await coordinator.dispatch(.next, request: runningRequest)
        let events = await runtime.events
        XCTAssertEqual(first, .launchTimedOut)
        XCTAssertEqual(second, .launchBlocked)
        XCTAssertEqual(third, .delivered)
        XCTAssertEqual(events, ["launch-begin", "launch-end", "dispatch-next"])
    }

    func testHangingLaunchDoesNotBlockLaterDispatchCalls() async {
        let runtime = HangingLaunchPlayerRuntime()
        let coordinator = PlayerLaunchCoordinator(runtime: runtime, timeout: .milliseconds(20))
        let launchRequest = PlayerDispatchRequest(selection: .launch(.spotify))
        let runningRequest = PlayerDispatchRequest(selection: .running(.spotify))

        let first = await coordinator.dispatch(.playPause, request: launchRequest)
        let clock = ContinuousClock()
        let startedAt = clock.now
        let second = await coordinator.dispatch(.next, request: runningRequest)
        let elapsed = startedAt.duration(to: clock.now)

        XCTAssertEqual(first, .launchTimedOut)
        XCTAssertEqual(second, .launchBlocked)
        XCTAssertLessThan(elapsed, .seconds(1))
        let dispatchCount = await runtime.dispatchCount
        XCTAssertEqual(dispatchCount, 0)

        await runtime.finishLaunch()
    }

    func testQueuedLaunchExpiresBeforeThePreviousGestureFinishes() async {
        let runtime = RecordingPlayerRuntime(
            runningAfterChecks: 0,
            dispatchDelay: .milliseconds(100)
        )
        let coordinator = PlayerLaunchCoordinator(runtime: runtime, timeout: .milliseconds(20))
        let runningRequest = PlayerDispatchRequest(selection: .running(.spotify))
        let launchRequest = PlayerDispatchRequest(selection: .launch(.spotify))

        let firstTask = Task {
            await coordinator.dispatch(.playPause, request: runningRequest)
        }
        await runtime.waitForDispatchCount(1)
        let secondTask = Task {
            await coordinator.dispatch(.next, request: launchRequest)
        }

        let second = await secondTask.value
        let first = await firstTask.value
        let launches = await runtime.launches
        let dispatches = await runtime.dispatches

        XCTAssertEqual(second, .launchTimedOut)
        XCTAssertEqual(first, .dispatchTimedOut)
        XCTAssertTrue(launches.isEmpty)
        XCTAssertEqual(dispatches, [DispatchRecord(key: .playPause, player: .spotify)])
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
        XCTAssertEqual(first, .delivered)
        XCTAssertEqual(second, .delivered)
        XCTAssertEqual(dispatches.map(\.key), [.playPause, .next])
        XCTAssertEqual(maximumConcurrentDispatches, 1)
    }
}

private actor RecordingPlayerRuntime: PlayerLaunchRuntime {
    private(set) var launches: [SupportedPlayer] = []
    private(set) var dispatches: [DispatchRecord] = []
    private(set) var events: [String] = []
    private(set) var maximumConcurrentDispatches = 0
    private var activeDispatches = 0
    private var runningChecks = 0
    private let runningAfterChecks: Int
    private let dispatchDelay: Duration
    private let launchDelay: Duration
    private let ignoresDispatchCancellation: Bool
    private let ignoresLaunchCancellation: Bool
    private let launchResult: Bool
    private let dispatchResult: Bool

    init(
        runningAfterChecks: Int,
        dispatchDelay: Duration = .zero,
        launchDelay: Duration = .zero,
        ignoresDispatchCancellation: Bool = false,
        ignoresLaunchCancellation: Bool = false,
        launchResult: Bool = true,
        dispatchResult: Bool = true
    ) {
        self.runningAfterChecks = runningAfterChecks
        self.dispatchDelay = dispatchDelay
        self.launchDelay = launchDelay
        self.ignoresDispatchCancellation = ignoresDispatchCancellation
        self.ignoresLaunchCancellation = ignoresLaunchCancellation
        self.launchResult = launchResult
        self.dispatchResult = dispatchResult
    }

    func launch(player: SupportedPlayer, applicationURL: URL?) async -> Bool {
        launches.append(player)
        events.append("launch-begin")
        if launchDelay > .zero {
            if ignoresLaunchCancellation {
                let delay = launchDelay
                await Task.detached {
                    try? await Task.sleep(for: delay)
                }.value
            } else {
                try? await Task.sleep(for: launchDelay)
            }
        }
        events.append("launch-end")
        return launchResult
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
        events.append("dispatch-\(key)")
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
        return dispatchResult
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

private actor FailFirstDispatchPlayerRuntime: PlayerLaunchRuntime {
    private(set) var launches: [SupportedPlayer] = []
    private(set) var dispatches: [DispatchRecord] = []
    private var dispatchResults = [false, true]

    func launch(player: SupportedPlayer, applicationURL: URL?) async -> Bool {
        launches.append(player)
        return true
    }

    func isRunning(player: SupportedPlayer, applicationURL: URL?) async -> Bool {
        true
    }

    func dispatch(
        key: MediaKey,
        player: SupportedPlayer,
        executableURL: URL?,
        applicationURL: URL?
    ) async -> Bool {
        dispatches.append(DispatchRecord(key: key, player: player))
        return dispatchResults.removeFirst()
    }
}

private actor HangingLaunchPlayerRuntime: PlayerLaunchRuntime {
    private var launchFinished = false
    private(set) var dispatchCount = 0

    func launch(player: SupportedPlayer, applicationURL: URL?) async -> Bool {
        while !launchFinished {
            await Task.yield()
        }
        return true
    }

    func isRunning(player: SupportedPlayer, applicationURL: URL?) async -> Bool {
        true
    }

    func dispatch(
        key: MediaKey,
        player: SupportedPlayer,
        executableURL: URL?,
        applicationURL: URL?
    ) async -> Bool {
        dispatchCount += 1
        return true
    }

    func finishLaunch() {
        launchFinished = true
    }
}

private actor HangingDispatchPlayerRuntime: PlayerLaunchRuntime {
    private var dispatchFinished = false
    private(set) var dispatchCount = 0

    func launch(player: SupportedPlayer, applicationURL: URL?) async -> Bool {
        true
    }

    func isRunning(player: SupportedPlayer, applicationURL: URL?) async -> Bool {
        true
    }

    func dispatch(
        key: MediaKey,
        player: SupportedPlayer,
        executableURL: URL?,
        applicationURL: URL?
    ) async -> Bool {
        dispatchCount += 1
        while !dispatchFinished {
            await Task.yield()
        }
        return true
    }

    func waitForDispatchCount(_ expected: Int) async {
        while dispatchCount < expected {
            await Task.yield()
        }
    }

    func finishDispatch() {
        dispatchFinished = true
    }
}
