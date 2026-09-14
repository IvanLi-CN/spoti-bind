import Foundation

public enum PlayerMode: String, CaseIterable, Codable, Sendable, Equatable {
    case automatic
    case spotify
    case fastpotify
    case sonora
    case spotifly
    case off

    public var displayName: String {
        switch self {
        case .automatic: "Automatic"
        case .spotify: "Spotify"
        case .fastpotify: "Fastpotify"
        case .sonora: "Sonora"
        case .spotifly: "Spotifly"
        case .off: "Off"
        }
    }

    var player: SupportedPlayer? {
        switch self {
        case .spotify: .spotify
        case .fastpotify: .fastpotify
        case .sonora: .sonora
        case .spotifly: .spotifly
        case .automatic, .off: nil
        }
    }
}

public enum SupportedPlayer: String, CaseIterable, Codable, Sendable, Equatable {
    case spotify
    case fastpotify
    case sonora
    case spotifly

    public var displayName: String {
        switch self {
        case .spotify: "Spotify"
        case .fastpotify: "Fastpotify"
        case .sonora: "Sonora"
        case .spotifly: "Spotifly"
        }
    }

    public var bundleIdentifier: String? {
        switch self {
        case .spotify:
            "com.spotify.client"
        case .fastpotify:
            nil
        case .sonora:
            "dev.nolight.sonora"
        case .spotifly:
            "rvdh.Spotifly"
        }
    }

    fileprivate var automaticSortOrder: Int {
        switch self {
        case .spotify: 0
        case .fastpotify: 1
        case .sonora: 2
        case .spotifly: 3
        }
    }
}

public struct PlayerAvailability: Sendable, Equatable {
    public let player: SupportedPlayer
    public let isInstalled: Bool
    public let isRunning: Bool
    public let canLaunch: Bool
    public let requiresLaunch: Bool

    public init(
        player: SupportedPlayer,
        isInstalled: Bool,
        isRunning: Bool,
        canLaunch: Bool,
        requiresLaunch: Bool = false
    ) {
        self.player = player
        self.isInstalled = isInstalled
        self.isRunning = isRunning
        self.canLaunch = canLaunch
        self.requiresLaunch = requiresLaunch
    }
}

public struct PlayerAvailabilitySnapshot: Sendable, Equatable {
    private let values: [SupportedPlayer: PlayerAvailability]

    public init(_ availabilities: [PlayerAvailability] = []) {
        values = Dictionary(uniqueKeysWithValues: availabilities.map { ($0.player, $0) })
    }

    public subscript(player: SupportedPlayer) -> PlayerAvailability {
        values[player] ?? PlayerAvailability(
            player: player,
            isInstalled: false,
            isRunning: false,
            canLaunch: false
        )
    }

    public var all: [PlayerAvailability] {
        SupportedPlayer.allCases.map { self[$0] }
    }
}

public enum PlayerSelection: Sendable, Equatable {
    case none
    case running(SupportedPlayer)
    case launch(SupportedPlayer)

    public var player: SupportedPlayer? {
        switch self {
        case .none: nil
        case .running(let player), .launch(let player): player
        }
    }
}

public struct PlayerSelectionResolver: Sendable {
    public init() {}

    public func resolve(
        mode: PlayerMode,
        snapshot: PlayerAvailabilitySnapshot
    ) -> PlayerSelection {
        switch mode {
        case .off:
            return .none
        case .automatic:
            let ordered = SupportedPlayer.allCases.sorted { $0.automaticSortOrder < $1.automaticSortOrder }
            if let running = ordered.first(where: { snapshot[$0].isRunning }) {
                return snapshot[running].requiresLaunch ? .launch(running) : .running(running)
            }
            if let launchable = ordered.first(where: {
                let availability = snapshot[$0]
                return availability.isInstalled && availability.canLaunch
            }) {
                return .launch(launchable)
            }
            return .none
        case .spotify, .fastpotify, .sonora, .spotifly:
            guard let player = mode.player else { return .none }
            let availability = snapshot[player]
            if availability.isRunning {
                return availability.requiresLaunch ? .launch(player) : .running(player)
            }
            if availability.isInstalled && availability.canLaunch {
                return .launch(player)
            }
            return .none
        }
    }
}

public struct KeyboardShortcut: Sendable, Equatable {
    public struct Modifiers: OptionSet, Sendable, Equatable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let control = Modifiers(rawValue: 1 << 1)
    }

    public let keyCode: UInt16
    public let modifiers: Modifiers

    public init(keyCode: UInt16, modifiers: Modifiers = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public enum PlayerDispatch: Sendable, Equatable {
    case fastpotify(FastpotifyCommand)
    case keyboard(KeyboardShortcut)

    public static func command(for key: MediaKey, player: SupportedPlayer) -> PlayerDispatch {
        switch player {
        case .fastpotify:
            .fastpotify(key.fastpotifyCommand)
        case .spotify:
            .keyboard(spotifyShortcut(for: key))
        case .sonora:
            .keyboard(shortcut(for: key, modifiers: key == .playPause ? [] : .control))
        case .spotifly:
            .keyboard(shortcut(for: key, modifiers: key == .playPause ? [] : .command))
        }
    }

    private static func shortcut(
        for key: MediaKey,
        modifiers: KeyboardShortcut.Modifiers
    ) -> KeyboardShortcut {
        switch key {
        case .playPause:
            KeyboardShortcut(keyCode: 49, modifiers: modifiers)
        case .next:
            KeyboardShortcut(keyCode: 124, modifiers: modifiers)
        case .previous:
            KeyboardShortcut(keyCode: 123, modifiers: modifiers)
        }
    }

    private static func spotifyShortcut(for key: MediaKey) -> KeyboardShortcut {
        switch key {
        case .playPause:
            KeyboardShortcut(keyCode: 49)
        case .next:
            KeyboardShortcut(keyCode: 125)
        case .previous:
            KeyboardShortcut(keyCode: 126)
        }
    }
}

public struct PlayerDispatchRequest: Sendable, Equatable {
    public let selection: PlayerSelection
    public let executableURL: URL?
    public let applicationURL: URL?

    public init(
        selection: PlayerSelection,
        executableURL: URL? = nil,
        applicationURL: URL? = nil
    ) {
        self.selection = selection
        self.executableURL = executableURL
        self.applicationURL = applicationURL
    }
}

public protocol PlayerLaunchRuntime: Sendable {
    func launch(player: SupportedPlayer, applicationURL: URL?) async -> Bool
    func isRunning(player: SupportedPlayer, applicationURL: URL?) async -> Bool
    func dispatch(
        key: MediaKey,
        player: SupportedPlayer,
        executableURL: URL?,
        applicationURL: URL?
    ) async -> Bool
}

public enum PlayerDispatchResult: Sendable, Equatable {
    case delivered
    case launchFailed
    case launchTimedOut
    case targetNotReady
    case dispatchFailed
    case dispatchTimedOut
    case launchBlocked

    public var isDelivered: Bool {
        self == .delivered
    }
}

public protocol PlayerDispatching: Sendable {
    func dispatch(
        _ key: MediaKey,
        request: PlayerDispatchRequest
    ) async -> PlayerDispatchResult
}

private final class BoolTimeoutGate: @unchecked Sendable {
    private let lock = NSLock()
    private let continuation: CheckedContinuation<Bool?, Never>
    private var didFinish = false
    private var operationTask: Task<Void, Never>?
    private var timeoutWorkItem: DispatchWorkItem?

    init(continuation: CheckedContinuation<Bool?, Never>) {
        self.continuation = continuation
    }

    func attach(
        operationTask: Task<Void, Never>,
        timeoutWorkItem: DispatchWorkItem
    ) {
        lock.lock()
        if didFinish {
            lock.unlock()
            operationTask.cancel()
            timeoutWorkItem.cancel()
            return
        }
        self.operationTask = operationTask
        self.timeoutWorkItem = timeoutWorkItem
        lock.unlock()
    }

    func finish(_ value: Bool?) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        let operationTask = self.operationTask
        let timeoutWorkItem = self.timeoutWorkItem
        lock.unlock()

        operationTask?.cancel()
        timeoutWorkItem?.cancel()
        continuation.resume(returning: value)
    }
}

private func dispatchInterval(for duration: Duration) -> DispatchTimeInterval {
    let components = duration.components
    let seconds = max(0, components.seconds)
    let attoseconds = max(0, components.attoseconds)
    let nanosecondsPerSecond: Int64 = 1_000_000_000
    let attosecondsPerNanosecond: Int64 = 1_000_000_000
    let maxSeconds = Int64(Int.max) / nanosecondsPerSecond
    guard seconds <= maxSeconds else { return .seconds(Int.max) }
    let totalNanoseconds = seconds * nanosecondsPerSecond
        + min(attoseconds / attosecondsPerNanosecond, Int64(Int.max) - seconds * nanosecondsPerSecond)
    return .nanoseconds(Int(totalNanoseconds))
}

private func boolWithinTimeout(
    _ timeout: Duration,
    operation: @escaping @Sendable () async -> Bool
) async -> Bool? {
    await withCheckedContinuation { continuation in
        let gate = BoolTimeoutGate(continuation: continuation)
        let operationTask = Task {
            gate.finish(await operation())
        }
        let timeoutWorkItem = DispatchWorkItem {
            gate.finish(nil)
        }
        gate.attach(operationTask: operationTask, timeoutWorkItem: timeoutWorkItem)
        if timeout <= .zero {
            gate.finish(nil)
        } else {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + dispatchInterval(for: timeout),
                execute: timeoutWorkItem
            )
        }
    }
}

private enum DispatchPhase: Sendable {
    case queued
    case launching
    case waitingForTarget
    case dispatching
}

private final class DispatchAttemptState: @unchecked Sendable {
    private let lock = NSLock()
    private var currentPhase: DispatchPhase = .queued

    func set(_ phase: DispatchPhase) {
        lock.lock()
        currentPhase = phase
        lock.unlock()
    }

    func phase() -> DispatchPhase {
        lock.lock()
        defer { lock.unlock() }
        return currentPhase
    }
}

public actor PlayerLaunchCoordinator: PlayerDispatching {
    private let runtime: any PlayerLaunchRuntime
    private let timeout: Duration
    private var pending: Task<PlayerDispatchResult, Never>?
    private var launchBarrierActive = false

    public init(
        runtime: any PlayerLaunchRuntime,
        timeout: Duration = .seconds(10)
    ) {
        self.runtime = runtime
        self.timeout = timeout
    }

    public func dispatch(
        _ key: MediaKey,
        request: PlayerDispatchRequest
    ) async -> PlayerDispatchResult {
        let isLaunchRequest: Bool
        if case .launch = request.selection {
            isLaunchRequest = true
        } else {
            isLaunchRequest = false
        }
        if launchBarrierActive {
            return .launchBlocked
        }
        if isLaunchRequest {
            launchBarrierActive = true
        }

        let previous = pending
        let runtime = runtime
        let timeout = timeout
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        let attemptState = DispatchAttemptState()
        let operation = Task<PlayerDispatchResult, Never> {
            if let previous {
                let remaining = clock.now.duration(to: deadline)
                guard remaining > .zero else {
                    // Keep this operation in the serial tail even when its
                    // own deadline has already expired. It must not permit a
                    // later gesture to overlap the unresolved predecessor.
                    _ = await previous.value
                    if isLaunchRequest {
                        self.setLaunchBarrier(active: false)
                    }
                    return isLaunchRequest ? .launchTimedOut : .dispatchTimedOut
                }

                let previousCompleted = await boolWithinTimeout(remaining, operation: {
                    _ = await previous.value
                    return true
                })
                guard previousCompleted != nil else {
                    // The caller receives its deadline result, while this
                    // queue operation drains the predecessor without ever
                    // executing a launch or dispatch side effect.
                    _ = await previous.value
                    if isLaunchRequest {
                        self.setLaunchBarrier(active: false)
                    }
                    return isLaunchRequest ? .launchTimedOut : .dispatchTimedOut
                }

                let previousResult = await previous.value
                guard clock.now.duration(to: deadline) > .zero else {
                    if isLaunchRequest {
                        self.setLaunchBarrier(active: false)
                    }
                    return isLaunchRequest ? .launchTimedOut : .dispatchTimedOut
                }
                if isLaunchRequest, !previousResult.isDelivered {
                    self.setLaunchBarrier(active: false)
                    return .launchTimedOut
                }
            }
            guard let player = request.selection.player else {
                if isLaunchRequest {
                    self.setLaunchBarrier(active: false)
                }
                return .dispatchFailed
            }

            switch request.selection {
            case .none:
                return .dispatchFailed
            case .running:
                attemptState.set(.dispatching)
                let dispatchBudget = clock.now.duration(to: deadline)
                guard dispatchBudget > .zero else { return .dispatchTimedOut }
                let dispatchTask = Task {
                    await runtime.dispatch(
                        key: key,
                        player: player,
                        executableURL: request.executableURL,
                        applicationURL: request.applicationURL
                    )
                }
                guard let result = await boolWithinTimeout(dispatchBudget, operation: {
                    await dispatchTask.value
                }) else {
                    dispatchTask.cancel()
                    _ = await dispatchTask.value
                    return .dispatchTimedOut
                }
                guard clock.now.duration(to: deadline) > .zero else {
                    return .dispatchTimedOut
                }
                return result ? .delivered : .dispatchFailed
            case .launch:
                attemptState.set(.launching)
                let launchBudget = clock.now.duration(to: deadline)
                guard launchBudget > .zero else {
                    self.setLaunchBarrier(active: false)
                    return .launchTimedOut
                }
                let launchTask = Task {
                    await runtime.launch(player: player, applicationURL: request.applicationURL)
                }
                let launchResult = await boolWithinTimeout(
                    launchBudget,
                    operation: {
                        await launchTask.value
                    }
                )
                if launchResult == nil {
                    // Keep the barrier active until a cancellation-insensitive
                    // launch has finished its side effect. The outer wait
                    // returns the timeout result to the caller at the deadline,
                    // while this operation remains the serial queue tail.
                    _ = await launchTask.value
                    self.setLaunchBarrier(active: false)
                    return .launchTimedOut
                }
                self.setLaunchBarrier(active: false)
                guard launchResult == true else {
                    return .launchFailed
                }
                guard clock.now.duration(to: deadline) > .zero else {
                    return .launchTimedOut
                }

                attemptState.set(.waitingForTarget)
                while true {
                    let remaining = clock.now.duration(to: deadline)
                    guard remaining > .zero else { return .targetNotReady }
                    if await boolWithinTimeout(remaining, operation: {
                        await runtime.isRunning(player: player, applicationURL: request.applicationURL)
                    }) == true {
                        attemptState.set(.dispatching)
                        let dispatchBudget = clock.now.duration(to: deadline)
                        guard dispatchBudget > .zero else { return .dispatchTimedOut }
                        let dispatchTask = Task {
                            await runtime.dispatch(
                                key: key,
                                player: player,
                                executableURL: request.executableURL,
                                applicationURL: request.applicationURL
                            )
                        }
                        let result = await boolWithinTimeout(dispatchBudget, operation: {
                            await dispatchTask.value
                        })
                        if result == nil {
                            // Keep this operation pending until a runtime that
                            // ignores cancellation has finished its side effect.
                            dispatchTask.cancel()
                            _ = await dispatchTask.value
                        }
                        guard let result else { return .dispatchTimedOut }
                        guard clock.now.duration(to: deadline) > .zero else {
                            return .dispatchTimedOut
                        }
                        return result ? .delivered : .dispatchFailed
                    }

                    let sleepDuration = clock.now.duration(to: deadline)
                    guard sleepDuration > .zero else { return .targetNotReady }
                    try? await Task.sleep(for: min(.milliseconds(100), sleepDuration))
                }
            }
        }
        pending = operation
        let completed = await boolWithinTimeout(timeout, operation: {
            await operation.value.isDelivered
        })
        guard completed != nil else {
            switch attemptState.phase() {
            case .dispatching:
                return .dispatchTimedOut
            case .queued, .launching:
                return isLaunchRequest ? .launchTimedOut : .dispatchTimedOut
            case .waitingForTarget:
                return .targetNotReady
            }
        }
        return await operation.value
    }

    private func setLaunchBarrier(active: Bool) {
        launchBarrierActive = active
    }
}

public enum PlayerModeMigration {
    public static func mode(
        storedMode: String?,
        legacyForwardingEnabled: Bool?
    ) -> PlayerMode {
        if let storedMode, let mode = PlayerMode(rawValue: storedMode) {
            return mode
        }
        if legacyForwardingEnabled == false {
            return .off
        }
        return .automatic
    }
}
