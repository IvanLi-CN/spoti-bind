@preconcurrency import Foundation
import SpotiBindCore

struct SystemProcessRunner: FastpotifyProcessRunner {
    func run(
        executableURL: URL,
        arguments: [String],
        timeout: Duration
    ) async -> ProcessExecution {
        await withCheckedContinuation { continuation in
            let gate = ProcessCompletionGate(continuation: continuation)
            let box = ProcessBox()
            box.process.executableURL = executableURL
            box.process.arguments = arguments

            let outputPipe = Pipe()
            box.process.standardOutput = outputPipe
            box.process.standardError = outputPipe
            box.process.terminationHandler = { process in
                let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
                gate.finish(
                    ProcessExecution(
                        exitCode: process.terminationStatus,
                        timedOut: false,
                        output: String(data: output, encoding: .utf8) ?? ""
                    )
                )
            }

            do {
                try box.process.run()
            } catch {
                gate.finish(
                    ProcessExecution(
                        exitCode: nil,
                        timedOut: false,
                        output: error.localizedDescription
                    )
                )
                return
            }

            Task.detached(priority: .utility) {
                try? await Task.sleep(for: timeout)
                guard !Task.isCancelled, box.process.isRunning else { return }
                box.process.terminate()
                gate.finish(ProcessExecution(exitCode: nil, timedOut: true))
            }
        }
    }
}

private final class ProcessBox: @unchecked Sendable {
    let process = Process()
}

private final class ProcessCompletionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ProcessExecution, Never>?

    init(continuation: CheckedContinuation<ProcessExecution, Never>) {
        self.continuation = continuation
    }

    func finish(_ result: ProcessExecution) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: result)
    }
}
