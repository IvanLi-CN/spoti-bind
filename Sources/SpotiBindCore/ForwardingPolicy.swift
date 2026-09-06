import Foundation

public struct ForwardingReadiness: Sendable, Equatable {
    public var forwardingEnabled: Bool
    public var accessibilityTrusted: Bool
    public var targetUsable: Bool
    public var probeHealthy: Bool

    public init(
        forwardingEnabled: Bool,
        accessibilityTrusted: Bool,
        targetUsable: Bool,
        probeHealthy: Bool
    ) {
        self.forwardingEnabled = forwardingEnabled
        self.accessibilityTrusted = accessibilityTrusted
        self.targetUsable = targetUsable
        self.probeHealthy = probeHealthy
    }

    public var isReady: Bool {
        forwardingEnabled && accessibilityTrusted && targetUsable && probeHealthy
    }
}

public enum RoutingDecision: Sendable, Equatable {
    case passThrough
    case consume
    case dispatch(FastpotifyCommand)
}

public enum TapFailureAction: Sendable, Equatable {
    case retryOnce
    case disableForwarding
}

public struct TapFailureTracker: Sendable, Equatable {
    public let retryWindow: TimeInterval
    private var lastFailureAt: Date?
    private var failureCount = 0

    public init(retryWindow: TimeInterval = 10) {
        self.retryWindow = max(0, retryWindow)
    }

    public mutating func recordFailure(at date: Date) -> TapFailureAction {
        if let lastFailureAt,
           date.timeIntervalSince(lastFailureAt) <= retryWindow {
            failureCount += 1
        } else {
            failureCount = 1
        }
        lastFailureAt = date
        return failureCount == 1 ? .retryOnce : .disableForwarding
    }

    public mutating func reset() {
        lastFailureAt = nil
        failureCount = 0
    }
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
            return .dispatch(event.key.fastpotifyCommand)
        case .repeatEvent, .up:
            return .consume
        }
    }
}
