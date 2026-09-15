import Foundation

public struct ForwardingReadiness: Sendable, Equatable {
    public var forwardingEnabled: Bool
    public var accessibilityTrusted: Bool
    public var targetUsable: Bool

    public init(
        forwardingEnabled: Bool,
        accessibilityTrusted: Bool,
        targetUsable: Bool
    ) {
        self.forwardingEnabled = forwardingEnabled
        self.accessibilityTrusted = accessibilityTrusted
        self.targetUsable = targetUsable
    }

    public var isReady: Bool {
        forwardingEnabled && accessibilityTrusted && targetUsable
    }
}

public enum RoutingDecision: Sendable, Equatable {
    case passThrough
    case consume
    case dispatch(MediaKey)
}

public struct RoutingPolicy: Sendable {
    public init() {}

    public func decision(
        for event: MediaKeyEvent,
        readiness: ForwardingReadiness
    ) -> RoutingDecision {
        guard readiness.isReady else {
            return .passThrough
        }

        switch event.phase {
        case .down:
            return .dispatch(event.key)
        case .repeatEvent, .up:
            return .consume
        }
    }
}
