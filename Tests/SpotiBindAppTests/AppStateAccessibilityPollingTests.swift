import XCTest
import SpotiBindCore
@testable import SpotiBind

@MainActor
final class AppStateAccessibilityPollingTests: XCTestCase {
    func testExplicitPermissionRequestPromptsOnceAndPollsUntilTrusted() async {
        let checker = RecordingTrustChecker(responses: [false, true])
        let scheduler = ManualPollingScheduler()
        let runner = RecordingProcessRunner()
        let state = makeState(
            checker: checker,
            scheduler: scheduler,
            runner: runner
        )

        var readinessChanges = 0
        state.onReadinessChanged = { readinessChanges += 1 }

        state.requestAccessibilityPermission()

        XCTAssertEqual(checker.prompts, [true])
        XCTAssertEqual(scheduler.scheduleCount, 1)
        XCTAssertEqual(scheduler.intervals, [1])
        XCTAssertFalse(state.accessibilityTrusted)
        let readinessChangesAfterRequest = readinessChanges

        scheduler.fire()

        XCTAssertTrue(state.accessibilityTrusted)
        XCTAssertTrue(scheduler.handle?.cancelled == true)
        XCTAssertEqual(readinessChanges, readinessChangesAfterRequest + 1)
        let calls = await runner.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testSettingsLinkStartsSilentPollingWithoutPrompting() {
        let checker = RecordingTrustChecker(responses: [true])
        let scheduler = ManualPollingScheduler()
        let opener = RecordingSettingsOpener()
        let state = makeState(
            checker: checker,
            scheduler: scheduler,
            opener: opener
        )

        state.openAccessibilitySettings()

        XCTAssertEqual(opener.openedURLs.count, 1)
        XCTAssertTrue(checker.prompts.isEmpty)
        XCTAssertEqual(scheduler.scheduleCount, 1)
        XCTAssertEqual(scheduler.intervals, [1])

        state.openAccessibilitySettings()
        XCTAssertEqual(scheduler.scheduleCount, 1)

        scheduler.fire()

        XCTAssertTrue(state.accessibilityTrusted)
        XCTAssertTrue(scheduler.handle?.cancelled == true)
    }

    func testOffModeAndStopCancelPendingAccessibilityPolling() {
        let checker = RecordingTrustChecker(responses: [false, false])
        let scheduler = ManualPollingScheduler()
        let state = makeState(checker: checker, scheduler: scheduler)

        state.requestAccessibilityPermission()
        XCTAssertFalse(scheduler.handle?.cancelled == true)

        state.setPlayerMode(.off)
        XCTAssertTrue(scheduler.handle?.cancelled == true)

        let secondScheduler = ManualPollingScheduler()
        let secondState = makeState(checker: checker, scheduler: secondScheduler)
        secondState.requestAccessibilityPermission()
        secondState.stop()
        XCTAssertTrue(secondScheduler.handle?.cancelled == true)
        let promptsBeforeStoppedFire = checker.prompts
        secondScheduler.fire()
        XCTAssertFalse(secondState.accessibilityTrusted)
        XCTAssertEqual(checker.prompts, promptsBeforeStoppedFire)
    }

    private func makeState(
        checker: RecordingTrustChecker,
        scheduler: ManualPollingScheduler,
        opener: RecordingSettingsOpener = RecordingSettingsOpener(),
        runner: RecordingProcessRunner = RecordingProcessRunner()
    ) -> AppState {
        let defaults = UserDefaults(suiteName: "SpotiBindTests.\(UUID().uuidString)")!
        defaults.set(PlayerMode.spotify.rawValue, forKey: "playerMode")
        let dispatcher = FastpotifyCommandDispatcher(runner: runner)
        return AppState(
            defaults: defaults,
            dispatcher: dispatcher,
            accessibilityTrustChecker: checker,
            accessibilityPollingScheduler: scheduler,
            accessibilitySettingsOpener: opener
        )
    }
}

@MainActor
private final class RecordingTrustChecker: AccessibilityTrustChecking {
    private var responses: [Bool]
    private(set) var prompts: [Bool] = []

    init(responses: [Bool]) {
        self.responses = responses
    }

    func check(prompt: Bool) -> Bool {
        prompts.append(prompt)
        if responses.count > 1 {
            return responses.removeFirst()
        }
        return responses.first ?? false
    }
}

@MainActor
private final class ManualPollingHandle: AccessibilityPollingHandle {
    private(set) var cancelled = false

    func cancel() {
        cancelled = true
    }
}

@MainActor
private final class ManualPollingScheduler: AccessibilityPollingScheduling {
    private(set) var scheduleCount = 0
    private(set) var intervals: [TimeInterval] = []
    private(set) var handle: ManualPollingHandle?
    private var action: (@MainActor () -> Void)?

    func scheduleRepeating(
        every interval: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) -> any AccessibilityPollingHandle {
        scheduleCount += 1
        intervals.append(interval)
        self.action = action
        let handle = ManualPollingHandle()
        self.handle = handle
        return handle
    }

    func fire() {
        action?()
    }
}

@MainActor
private final class RecordingSettingsOpener: AccessibilitySettingsOpening {
    private(set) var openedURLs: [URL] = []

    func open(_ url: URL) -> Bool {
        openedURLs.append(url)
        return true
    }
}

private actor RecordingProcessRunner: FastpotifyProcessRunner {
    private(set) var calls: [[String]] = []

    func run(
        executableURL: URL,
        arguments: [String],
        timeout: Duration
    ) async -> ProcessExecution {
        calls.append(arguments)
        return ProcessExecution(exitCode: 0, timedOut: false)
    }
}
