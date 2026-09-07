import Foundation

public enum MediaKeyEventHandling: Sendable, Equatable {
    case passThrough
    case route(RoutingDecision)
}

/// Keeps the event-tap boundary narrow: only the exact system-defined event
/// type may reach media-key decoding and routing.
public struct MediaKeyEventRouter: Sendable {
    private let policy: RoutingPolicy

    public init(policy: RoutingPolicy = RoutingPolicy()) {
        self.policy = policy
    }

    public func decision(
        eventType: UInt32,
        systemDefinedEventType: UInt32,
        data1: UInt32?,
        readiness: ForwardingReadiness
    ) -> MediaKeyEventHandling {
        guard eventType == systemDefinedEventType, let data1 else {
            return .passThrough
        }
        guard let decoded = SystemDefinedMediaKeyDecoder().decode(data1: data1) else {
            return .passThrough
        }
        return .route(policy.decision(for: decoded, readiness: readiness))
    }
}
