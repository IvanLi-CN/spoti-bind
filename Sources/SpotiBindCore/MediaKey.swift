import Foundation

public enum MediaKey: String, CaseIterable, Sendable, Equatable {
    case playPause
    case next
    case previous

    public var fastpotifyCommand: FastpotifyCommand {
        switch self {
        case .playPause:
            .playPause
        case .next:
            .next
        case .previous:
            .previous
        }
    }
}

public enum MediaKeyPhase: Sendable, Equatable {
    case down
    case up
    case repeatEvent
}

public struct MediaKeyEvent: Sendable, Equatable {
    public let key: MediaKey
    public let phase: MediaKeyPhase

    public init(key: MediaKey, phase: MediaKeyPhase) {
        self.key = key
        self.phase = phase
    }
}

public enum FastpotifyCommand: String, CaseIterable, Sendable, Equatable {
    case playPause = "play-pause"
    case next
    case previous

    public var arguments: [String] {
        [rawValue]
    }
}

public struct SystemDefinedMediaKeyDecoder: Sendable {
    public init() {}

    /// Decodes the public NSEvent systemDefined data1 payload.
    /// The high 16 bits contain the NX key type; the low 16 bits contain state flags.
    public func decode(data1: UInt32) -> MediaKeyEvent? {
        let keyCode = UInt16((data1 >> 16) & 0xffff)
        let flags = UInt16(data1 & 0xffff)
        let state = UInt8((flags >> 8) & 0xff)
        let isRepeat = (flags & 0x0001) != 0

        let key: MediaKey
        switch keyCode {
        case 16:
            key = .playPause
        case 17:
            key = .next
        case 18:
            key = .previous
        default:
            return nil
        }

        switch state {
        case 0x0a:
            return MediaKeyEvent(key: key, phase: isRepeat ? .repeatEvent : .down)
        case 0x0b:
            return MediaKeyEvent(key: key, phase: .up)
        default:
            return nil
        }
    }
}
