import AppKit
import Foundation
import SpotiBindCore

enum UIAppearance: String, CaseIterable, Sendable {
    case light
    case dark

    var nsAppearance: NSAppearance.Name {
        switch self {
        case .light: .aqua
        case .dark: .darkAqua
        }
    }

    static func parse(environment: [String: String]) -> UIAppearance? {
        guard let rawValue = environment["SPOTIBIND_UI_APPEARANCE"] else {
            return .light
        }
        return UIAppearance(rawValue: rawValue)
    }
}

enum UIDemoScenario: String, CaseIterable, Sendable {
    case healthy
    case accessibilityRequired = "accessibility-required"
    case noSupportedPlayer = "no-supported-player"
    case pathUnavailable = "path-unavailable"
    case dispatchFailure = "dispatch-failure"

    static func parse(environment: [String: String]) -> UIDemoScenario? {
        guard environment["SPOTIBIND_UI_DEMO"] == "1" else { return nil }
        return UIDemoScenario(rawValue: environment["SPOTIBIND_UI_DEMO_SCENE"] ?? "healthy")
    }
}

struct UIDemoConfiguration: Equatable, Sendable {
    let scenario: UIDemoScenario
    let appearance: UIAppearance
    let playerMode: PlayerMode
    let accessibilityTrusted: Bool
    let probeHealthy: Bool
    let tapStatus: String
    let dispatchFailure: String?
    let availability: PlayerAvailabilitySnapshot
    let pathSettings: PlayerPathSettings
    let pathStates: [SupportedPlayer: PlayerPathState]
    let pathProblems: [SupportedPlayer: String]

    static func parse(environment: [String: String]) -> UIDemoConfiguration? {
        guard let scenario = UIDemoScenario.parse(environment: environment),
              let appearance = UIAppearance.parse(environment: environment) else {
            return nil
        }
        return UIDemoConfiguration(scenario: scenario, appearance: appearance)
    }

    init(scenario: UIDemoScenario, appearance: UIAppearance = .light) {
        self.scenario = scenario
        self.appearance = appearance

        let neutralSonoraPath = URL(fileURLWithPath: "/Demo/Applications/Sonora.app")
        let neutralPathSettings = PlayerPathSettings()
        let healthyAvailability = PlayerAvailabilitySnapshot([
            PlayerAvailability(
                player: .fastpotify,
                isInstalled: true,
                isRunning: false,
                canLaunch: true
            ),
            PlayerAvailability(
                player: .sonora,
                isInstalled: true,
                isRunning: true,
                canLaunch: true
            ),
            PlayerAvailability(
                player: .spotifly,
                isInstalled: true,
                isRunning: false,
                canLaunch: true
            )
        ])

        switch scenario {
        case .healthy:
            playerMode = .sonora
            accessibilityTrusted = true
            probeHealthy = true
            tapStatus = "Ready"
            dispatchFailure = nil
            availability = healthyAvailability
            pathSettings = neutralPathSettings
            pathStates = [:]
            pathProblems = [:]
        case .accessibilityRequired:
            playerMode = .sonora
            accessibilityTrusted = false
            probeHealthy = true
            tapStatus = "Ready"
            dispatchFailure = nil
            availability = healthyAvailability
            pathSettings = neutralPathSettings
            pathStates = [:]
            pathProblems = [:]
        case .noSupportedPlayer:
            playerMode = .automatic
            accessibilityTrusted = true
            probeHealthy = false
            tapStatus = "Ready"
            dispatchFailure = nil
            availability = PlayerAvailabilitySnapshot()
            pathSettings = neutralPathSettings
            pathStates = [:]
            pathProblems = [:]
        case .pathUnavailable:
            playerMode = .sonora
            accessibilityTrusted = true
            probeHealthy = true
            tapStatus = "Ready"
            dispatchFailure = nil
            availability = healthyAvailability
            var settings = neutralPathSettings
            settings.set(.custom(neutralSonoraPath), for: .sonora)
            pathSettings = settings
            pathStates = [.sonora: .custom(neutralSonoraPath, valid: false)]
            pathProblems = [
                .sonora: "The saved Sonora path is unavailable. Choose a new path or reset it."
            ]
        case .dispatchFailure:
            playerMode = .sonora
            accessibilityTrusted = true
            probeHealthy = true
            tapStatus = "Ready"
            dispatchFailure = "Sonora media-key dispatch failed."
            availability = healthyAvailability
            pathSettings = neutralPathSettings
            pathStates = [:]
            pathProblems = [:]
        }
    }
}
