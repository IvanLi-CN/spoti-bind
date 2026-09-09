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
}
