import Foundation

public enum FastpotifyPathSource: String, Sendable, Equatable {
    case userSelected
    case knownLocation
}

public struct FastpotifyExecutable: Sendable, Equatable {
    public let url: URL
    public let source: FastpotifyPathSource

    public init(url: URL, source: FastpotifyPathSource) {
        self.url = url
        self.source = source
    }
}

public struct FastpotifyExecutableLocator: Sendable {
    public init() {}

    public func locate(userSelectedURL: URL? = nil) -> FastpotifyExecutable? {
        if let userSelectedURL, let executableURL = executableURL(for: userSelectedURL) {
            return FastpotifyExecutable(url: executableURL, source: .userSelected)
        }

        for candidate in knownCandidates {
            if let executableURL = executableURL(for: candidate) {
                return FastpotifyExecutable(url: executableURL, source: .knownLocation)
            }
        }

        return nil
    }

    public func executableURL(for url: URL) -> URL? {
        if url.pathExtension.caseInsensitiveCompare("app") == .orderedSame {
            let appName = url.deletingPathExtension().lastPathComponent
            let names = ["fastpotify", "Fastpotify", appName]
            for name in names where !name.isEmpty {
                let candidate = url
                    .appendingPathComponent("Contents", isDirectory: true)
                    .appendingPathComponent("MacOS", isDirectory: true)
                    .appendingPathComponent(name, isDirectory: false)
                if FileManager.default.isExecutableFile(atPath: candidate.path) {
                    return candidate
                }
            }
            return nil
        }

        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            return nil
        }
        return url
    }

    private var knownCandidates: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            URL(fileURLWithPath: "/Applications/Fastpotify.app"),
            home.appendingPathComponent("Applications/Fastpotify.app"),
            URL(fileURLWithPath: "/Applications/fastpotify"),
            home.appendingPathComponent("Applications/fastpotify"),
            URL(fileURLWithPath: "/opt/homebrew/bin/fastpotify"),
            URL(fileURLWithPath: "/usr/local/bin/fastpotify")
        ]
    }
}

public struct ProcessExecution: Sendable, Equatable {
    public let exitCode: Int32?
    public let timedOut: Bool
    public let output: String

    public init(exitCode: Int32?, timedOut: Bool, output: String = "") {
        self.exitCode = exitCode
        self.timedOut = timedOut
        self.output = output
    }

    public var succeeded: Bool {
        !timedOut && exitCode == 0
    }
}

public protocol FastpotifyProcessRunner: Sendable {
    func run(
        executableURL: URL,
        arguments: [String],
        timeout: Duration
    ) async -> ProcessExecution
}

public actor FastpotifyCommandDispatcher {
    private let runner: any FastpotifyProcessRunner
    private let timeout: Duration
    private var pending: Task<ProcessExecution, Never>?

    public init(
        runner: any FastpotifyProcessRunner,
        timeout: Duration = .seconds(2)
    ) {
        self.runner = runner
        self.timeout = timeout
    }

    public func dispatch(
        _ command: FastpotifyCommand,
        executableURL: URL
    ) async -> ProcessExecution {
        await enqueue(executableURL: executableURL, arguments: command.arguments)
    }

    public func probe(executableURL: URL) async -> Bool {
        let result = await enqueue(
            executableURL: executableURL,
            arguments: ["now-playing", "--raw"]
        )
        return result.succeeded
    }

    private func enqueue(
        executableURL: URL,
        arguments: [String]
    ) async -> ProcessExecution {
        let previous = pending
        let runner = runner
        let timeout = timeout
        let operation = Task<ProcessExecution, Never> {
            if let previous {
                _ = await previous.value
            }
            return await runner.run(
                executableURL: executableURL,
                arguments: arguments,
                timeout: timeout
            )
        }
        pending = operation
        return await operation.value
    }
}
