import XCTest
@testable import SpotiBindCore

final class RoutingPresentationTests: XCTestCase {
    func testAccessibilityIsActionableWithoutPromptingAtStartup() {
        let presentation = RoutingPresentation.make(
            mode: .automatic,
            accessibilityTrusted: false,
            issue: nil,
            selection: .none,
            tapStatus: "Starting",
            targetDetail: ""
        )

        XCTAssertEqual(presentation.title, "Accessibility permission required")
        XCTAssertEqual(presentation.action, .accessibility)
    }

    func testPathFailureOpensSettingsWithoutChangingMode() {
        let presentation = RoutingPresentation.make(
            mode: .fastpotify,
            accessibilityTrusted: true,
            issue: .pathUnavailable(
                player: .fastpotify,
                detail: "The custom path is unavailable."
            ),
            selection: .none,
            tapStatus: "Ready",
            targetDetail: ""
        )

        XCTAssertEqual(presentation.title, "Fastpotify path unavailable")
        XCTAssertEqual(presentation.action, .settings)
    }

    func testControlsRemainUnavailableWhenNoSelectionExists() {
        let presentation = RoutingPresentation.make(
            mode: .automatic,
            accessibilityTrusted: true,
            issue: nil,
            selection: .none,
            tapStatus: "Ready",
            targetDetail: ""
        )

        XCTAssertEqual(presentation.action, .settings)
    }

    func testDispatchFailureIsVisibleAndOffersSettingsOnly() {
        let presentation = RoutingPresentation.make(
            mode: .sonora,
            accessibilityTrusted: true,
            issue: .dispatchFailure(detail: "Sonora media-key dispatch failed."),
            selection: .running(.sonora),
            tapStatus: "Ready",
            targetDetail: "/Applications/Sonora.app"
        )

        XCTAssertEqual(presentation.title, "Media key dispatch failed")
        XCTAssertEqual(presentation.action, .settings)
    }

    func testPlayerLaunchFailureOffersFinderRecovery() {
        let presentation = RoutingPresentation.make(
            mode: .sonora,
            accessibilityTrusted: true,
            issue: .playerLaunchFailed(player: .sonora),
            selection: .launch(.sonora),
            tapStatus: "Ready",
            targetDetail: "/Applications/Sonora.app"
        )

        XCTAssertEqual(presentation.title, "Could not start Sonora")
        XCTAssertEqual(
            presentation.detail,
            "Open the app in Finder to approve it, then try again."
        )
        XCTAssertEqual(presentation.action, .revealInFinder(player: .sonora))
    }

    func testRestartedCaptureIsInformational() {
        let presentation = RoutingPresentation.make(
            mode: .automatic,
            accessibilityTrusted: true,
            issue: nil,
            selection: .running(.sonora),
            tapStatus: "Media key capture restarted",
            targetDetail: "/Applications/Sonora.app"
        )

        XCTAssertEqual(presentation.title, "Media key capture restarted")
        XCTAssertNil(presentation.action)
    }

    func testQuarantinedCaptureExplainsHowToResumeForwarding() {
        let presentation = RoutingPresentation.make(
            mode: .spotify,
            accessibilityTrusted: true,
            issue: nil,
            selection: .running(.spotify),
            tapStatus: "Media key capture paused",
            targetDetail: "/Applications/Spotify.app"
        )

        XCTAssertEqual(presentation.title, "Media key capture paused")
        XCTAssertEqual(
            presentation.detail,
            "Revoke and re-enable Accessibility to resume forwarding."
        )
        XCTAssertEqual(presentation.action, .accessibility)
    }
}
