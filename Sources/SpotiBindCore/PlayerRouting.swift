import Foundation

public enum PlayerMode: String, CaseIterable, Codable, Sendable, Equatable {
    case automatic
    case fastpotify
    case sonora
    case spotifly
    case off

    public var displayName: String {
        switch self {
        case .automatic: "Automatic"
        case .fastpotify: "Fastpotify"
        case .sonora: "Sonora"
        case .spotifly: "Spotifly"
        case .off: "Off"
        }
    }

    var player: SupportedPlayer? {
        switch self {
        case .fastpotify: .fastpotify
        case .sonora: .sonora
        case .spotifly: .spotifly
        case .automatic, .off: nil
        }
    }
}

public enum SupportedPlayer: String, CaseIterable, Codable, Sendable, Equatable {
    case fastpotify
    case sonora
    case spotifly

    public var displayName: String {
        switch self {
        case .fastpotify: "Fastpotify"
        case .sonora: "Sonora"
        case .spotifly: "Spotifly"
        }
    }

    public var bundleIdentifier: String? {
        switch self {
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
        case .fastpotify: 0
        case .sonora: 1
        case .spotifly: 2
        }
    }
}

public struct PlayerAvailability: Sendable, Equatable {
    public let player: SupportedPlayer
    public let isInstalled: Bool
    public let isRunning: Bool
    public let canLaunch: Bool

    public init(
        player: SupportedPlayer,
        isInstalled: Bool,
        isRunning: Bool,
        canLaunch: Bool
    ) {
        self.player = player
        self.isInstalled = isInstalled
        self.isRunning = isRunning
        self.canLaunch = canLaunch
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
                return .running(running)
            }
            if let launchable = ordered.first(where: {
                let availability = snapshot[$0]
                return availability.isInstalled && availability.canLaunch
            }) {
                return .launch(launchable)
            }
            return .none
        case .fastpotify, .sonora, .spotifly:
            guard let player = mode.player else { return .none }
            let availability = snapshot[player]
            if availability.isRunning {
                return .running(player)
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

public actor PlayerLaunchCoordinator {
    private let runtime: any PlayerLaunchRuntime
    private let timeout: Duration
    private var pending: Task<Bool, Never>?

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
    ) async -> Bool {
        let previous = pending
        let runtime = runtime
        let timeout = timeout
        let operation = Task<Bool, Never> {
            if let previous {
                _ = await previous.value
            }
            guard let player = request.selection.player else {
                return false
            }

            switch request.selection {
            case .none:
                return false
            case .running:
                return await runtime.dispatch(
                    key: key,
                    player: player,
                    executableURL: request.executableURL,
                    applicationURL: request.applicationURL
                )
            case .launch:
                guard await runtime.launch(player: player, applicationURL: request.applicationURL) else {
                    return false
                }
                let clock = ContinuousClock()
                let deadline = clock.now.advanced(by: timeout)
                while clock.now < deadline {
                    if await runtime.isRunning(player: player, applicationURL: request.applicationURL) {
                        return await runtime.dispatch(
                            key: key,
                            player: player,
                            executableURL: request.executableURL,
                            applicationURL: request.applicationURL
                        )
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                }
                return false
            }
        }
        pending = operation
        return await operation.value
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
