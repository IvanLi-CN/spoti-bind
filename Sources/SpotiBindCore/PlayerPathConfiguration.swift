import Foundation

public enum PlayerPathConfiguration: Codable, Sendable, Equatable {
    case automatic
    case custom(URL)
    case inheritLegacy
}

public struct PlayerPathSettings: Codable, Sendable, Equatable {
    private var values: [String: PlayerPathConfiguration]

    public init(values: [SupportedPlayer: PlayerPathConfiguration] = [:]) {
        self.values = Dictionary(uniqueKeysWithValues: values.map { ($0.key.rawValue, $0.value) })
    }

    public func configuration(for player: SupportedPlayer) -> PlayerPathConfiguration {
        if let stored = values[player.rawValue] {
            return stored
        }
        return player == .fastpotify ? .inheritLegacy : .automatic
    }

    public mutating func set(
        _ configuration: PlayerPathConfiguration,
        for player: SupportedPlayer
    ) {
        values[player.rawValue] = configuration
    }

    public var configuredPlayers: Set<SupportedPlayer> {
        Set(values.keys.compactMap(SupportedPlayer.init(rawValue:)))
    }
}
