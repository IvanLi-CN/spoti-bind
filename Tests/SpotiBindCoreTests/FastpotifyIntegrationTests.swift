import Foundation
import XCTest
@testable import SpotiBindCore

final class FastpotifyIntegrationTests: XCTestCase {
    func testCommandsExposeOnlyDocumentedArguments() {
        XCTAssertEqual(FastpotifyCommand.playPause.arguments, ["play-pause"])
        XCTAssertEqual(FastpotifyCommand.next.arguments, ["next"])
        XCTAssertEqual(FastpotifyCommand.previous.arguments, ["previous"])
    }

    func testDispatcherSerializesDistinctGesturesAndProbeUsesRawCommand() async {
        let runner = RecordingRunner()
        let dispatcher = FastpotifyCommandDispatcher(
            runner: runner,
            timeout: .seconds(2)
        )
        let executable = URL(fileURLWithPath: "/tmp/fastpotify")

        async let first = dispatcher.dispatch(.playPause, executableURL: executable)
        async let second = dispatcher.dispatch(.next, executableURL: executable)
        _ = await (first, second)
        _ = await dispatcher.probe(executableURL: executable)

        let calls = await runner.calls
        XCTAssertEqual(calls.count, 3)
        XCTAssertTrue(calls.contains(["play-pause"]))
        XCTAssertTrue(calls.contains(["next"]))
        XCTAssertTrue(calls.contains(["now-playing", "--raw"]))
    }

    func testDispatcherDoesNotOverlapProcessRuns() async {
        let runner = RecordingRunner(delay: .milliseconds(20))
        let dispatcher = FastpotifyCommandDispatcher(runner: runner)
        let executable = URL(fileURLWithPath: "/tmp/fastpotify")

        async let first = dispatcher.dispatch(.playPause, executableURL: executable)
        async let second = dispatcher.dispatch(.next, executableURL: executable)
        _ = await (first, second)

        let maximumConcurrentRuns = await runner.maximumConcurrentRuns
        XCTAssertEqual(maximumConcurrentRuns, 1)
    }

    func testDispatchFailureIsReturnedWithoutReplay() async {
        let runner = RecordingRunner(
            result: ProcessExecution(exitCode: 1, timedOut: false)
        )
        let dispatcher = FastpotifyCommandDispatcher(runner: runner)
        let executable = URL(fileURLWithPath: "/tmp/fastpotify")

        let result = await dispatcher.dispatch(.previous, executableURL: executable)

        XCTAssertFalse(result.succeeded)
        let calls = await runner.calls
        XCTAssertEqual(calls, [["previous"]])
    }

    func testSelectedExecutableTakesPrecedenceAndAppBundlesResolve() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("SpotiBindTests-\(UUID().uuidString)")
        let app = root.appendingPathComponent("Fastpotify.app")
        let executable = app
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("fastpotify")
        defer { try? fileManager.removeItem(at: root) }

        try fileManager.createDirectory(
            at: executable.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        XCTAssertTrue(fileManager.createFile(atPath: executable.path, contents: Data()))
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )

        let located = FastpotifyExecutableLocator().locate(userSelectedURL: app)

        XCTAssertEqual(located?.url, executable)
        XCTAssertEqual(located?.source, .userSelected)
    }

    func testProcessExecutionDoesNotTurnTimeoutIntoSuccess() {
        XCTAssertFalse(ProcessExecution(exitCode: 0, timedOut: true).succeeded)
        XCTAssertTrue(ProcessExecution(exitCode: 0, timedOut: false).succeeded)
        XCTAssertFalse(ProcessExecution(exitCode: 1, timedOut: false).succeeded)
    }
}

private actor RecordingRunner: FastpotifyProcessRunner {
    private(set) var calls: [[String]] = []
    private(set) var maximumConcurrentRuns = 0
    private var activeRuns = 0
    private let delay: Duration
    private let result: ProcessExecution

    init(
        delay: Duration = .zero,
        result: ProcessExecution = ProcessExecution(exitCode: 0, timedOut: false)
    ) {
        self.delay = delay
        self.result = result
    }

    func run(
        executableURL: URL,
        arguments: [String],
        timeout: Duration
    ) async -> ProcessExecution {
        activeRuns += 1
        maximumConcurrentRuns = max(maximumConcurrentRuns, activeRuns)
        calls.append(arguments)
        if delay > .zero {
            try? await Task.sleep(for: delay)
        }
        activeRuns -= 1
        return result
    }
}
