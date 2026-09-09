import SpotiBindCore
import XCTest
@testable import SpotiBind

final class UIDemoScenarioTests: XCTestCase {
    func testEnvironmentParsesEverySupportedScenario() {
        for scenario in UIDemoScenario.allCases {
            let configuration = UIDemoConfiguration.parse(environment: [
                "SPOTIBIND_UI_DEMO": "1",
                "SPOTIBIND_UI_DEMO_SCENE": scenario.rawValue,
                "SPOTIBIND_UI_APPEARANCE": "light"
            ])

            XCTAssertEqual(configuration?.scenario, scenario)
        }
    }

    func testHealthyScenarioProjectsTheFixedBaseline() {
        let configuration = UIDemoConfiguration(scenario: .healthy)

        XCTAssertEqual(configuration.playerMode, .sonora)
        XCTAssertTrue(configuration.accessibilityTrusted)
        XCTAssertTrue(configuration.probeHealthy)
        XCTAssertEqual(configuration.tapStatus, "Ready")
        XCTAssertNil(configuration.dispatchFailure)
        XCTAssertEqual(configuration.availability[.sonora].isRunning, true)
        XCTAssertTrue(configuration.availability.all.allSatisfy(\.isInstalled))
    }

    func testAutomaticSelectionScenarioKeepsTheHealthyBaseline() {
        let configuration = UIDemoConfiguration(scenario: .automaticSelection)

        XCTAssertEqual(configuration.playerMode, .automatic)
        XCTAssertTrue(configuration.accessibilityTrusted)
        XCTAssertTrue(configuration.probeHealthy)
        XCTAssertNil(configuration.dispatchFailure)
        XCTAssertTrue(configuration.availability.all.allSatisfy(\.isInstalled))
    }

    func testErrorScenariosRemainDeterministicAndUseNeutralState() {
        let accessibility = UIDemoConfiguration(scenario: .accessibilityRequired)
        XCTAssertFalse(accessibility.accessibilityTrusted)

        let noPlayer = UIDemoConfiguration(scenario: .noSupportedPlayer)
        XCTAssertEqual(noPlayer.availability.all, [
            PlayerAvailability(player: .fastpotify, isInstalled: false, isRunning: false, canLaunch: false),
            PlayerAvailability(player: .sonora, isInstalled: false, isRunning: false, canLaunch: false),
            PlayerAvailability(player: .spotifly, isInstalled: false, isRunning: false, canLaunch: false)
        ])

        let unavailablePath = UIDemoConfiguration(scenario: .pathUnavailable)
        XCTAssertTrue(unavailablePath.pathProblems[.sonora]?.contains("unavailable") == true)
        XCTAssertEqual(
            unavailablePath.pathState(for: .sonora),
            .custom(URL(fileURLWithPath: "/Demo/Applications/Sonora.app"), valid: false)
        )

        let failure = UIDemoConfiguration(scenario: .dispatchFailure)
        XCTAssertEqual(failure.dispatchFailure, "Sonora media-key dispatch failed.")
    }

    func testDemoIsDisabledWithoutTheExplicitSwitch() {
        XCTAssertNil(UIDemoConfiguration.parse(environment: [
            "SPOTIBIND_UI_DEMO_SCENE": UIDemoScenario.healthy.rawValue,
            "SPOTIBIND_UI_APPEARANCE": "dark"
        ]))
    }
}

private extension UIDemoConfiguration {
    func pathState(for player: SupportedPlayer) -> PlayerPathState? {
        pathStates[player]
    }
}
