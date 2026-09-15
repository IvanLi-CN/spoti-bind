import Foundation

public enum RoutingIssue: Equatable, Sendable {
    case pathUnavailable(player: SupportedPlayer, detail: String)
    case playerLaunchFailed(player: SupportedPlayer)
    case dispatchFailure(detail: String)
}

public enum RoutingStatusAction: Equatable, Sendable {
    case accessibility
    case settings
    case revealInFinder(player: SupportedPlayer)
}

public struct RoutingPresentation: Equatable, Sendable {
    public let title: String
    public let detail: String
    public let action: RoutingStatusAction?

    public init(
        title: String,
        detail: String,
        action: RoutingStatusAction? = nil
    ) {
        self.title = title
        self.detail = detail
        self.action = action
    }

    public static func make(
        mode: PlayerMode,
        accessibilityTrusted: Bool,
        issue: RoutingIssue?,
        selection: PlayerSelection,
        tapStatus: String,
        targetDetail: String
    ) -> RoutingPresentation {
        if mode == .off {
            return RoutingPresentation(
                title: "Forwarding disabled",
                detail: "Media keys follow the normal system route."
            )
        }
        if !accessibilityTrusted {
            return RoutingPresentation(
                title: "Accessibility permission required",
                detail: "Grant Accessibility access to capture media keys.",
                action: .accessibility
            )
        }
        if case .pathUnavailable(let player, let detail) = issue {
            return RoutingPresentation(
                title: "\(player.displayName) path unavailable",
                detail: detail,
                action: .settings
            )
        }
        if case .playerLaunchFailed(let player) = issue {
            return RoutingPresentation(
                title: "Could not start \(player.displayName)",
                detail: "Open the app in Finder to approve it, then try again.",
                action: .revealInFinder(player: player)
            )
        }
        if case .dispatchFailure(let detail) = issue {
            return RoutingPresentation(
                title: "Media key dispatch failed",
                detail: detail,
                action: .settings
            )
        }
        if tapStatus == "Media key capture paused" {
            return RoutingPresentation(
                title: tapStatus,
                detail: "Revoke and re-enable Accessibility to resume forwarding.",
                action: .accessibility
            )
        }
        switch selection {
        case .none:
            return RoutingPresentation(
                title: "No supported player found",
                detail: "Install or configure a supported player to continue.",
                action: .settings
            )
        case .launch(let player):
            return RoutingPresentation(
                title: "Starting \(player.displayName)",
                detail: targetDetail
            )
        case .running(let player):
            if tapStatus != "Ready" {
                return RoutingPresentation(
                    title: tapStatus,
                    detail: targetDetail
                )
            }
            return RoutingPresentation(
                title: "Forwarding to \(player.displayName)",
                detail: targetDetail
            )
        }
    }
}
