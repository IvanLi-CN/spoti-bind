import AppKit
import XCTest
@testable import SpotiBind

@MainActor
final class ApplicationPresentationTests: XCTestCase {
    func testRegularSettingsLifecycleReturnsToAccessoryAfterClose() {
        var policies: [NSApplication.ActivationPolicy] = []
        let controller = ApplicationPresentationController(isUIDemo: false) { policy in
            policies.append(policy)
            return true
        }

        controller.configureForLaunch()
        controller.settingsDidOpen()
        controller.settingsDidClose()

        XCTAssertEqual(policies, [.accessory, .regular, .accessory])
        XCTAssertEqual(controller.currentPolicy, .accessory)
    }

    func testDemoRemainsRegularWhenSettingsCloses() {
        var policies: [NSApplication.ActivationPolicy] = []
        let controller = ApplicationPresentationController(isUIDemo: true) { policy in
            policies.append(policy)
            return true
        }

        controller.configureForLaunch()
        controller.settingsDidOpen()
        controller.settingsDidClose()

        XCTAssertEqual(policies, [.regular])
        XCTAssertEqual(controller.currentPolicy, .regular)
    }

    func testFailedPolicyChangeDoesNotClaimItWasApplied() {
        var calls = 0
        let controller = ApplicationPresentationController(isUIDemo: false) { _ in
            calls += 1
            return false
        }

        controller.configureForLaunch()

        XCTAssertEqual(calls, 1)
        XCTAssertNil(controller.currentPolicy)
    }

    func testStatusBarTemplateLoadsFromBundle() {
        let image = StatusBarIcon.templateImage(bundle: .module)

        XCTAssertNotNil(image)
        XCTAssertTrue(image?.isTemplate == true)
        XCTAssertEqual(image?.size, NSSize(width: 18, height: 18))
    }

    func testProductionStatusBarTemplateRendersThroughAppKit() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("assets/spotibind-logo-monochrome.svg")

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        let image = try XCTUnwrap(StatusBarIcon.templateImage(url: sourceURL))
        let bitmap = try XCTUnwrap(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))

        XCTAssertGreaterThan(bitmap.pixelsWide, 0)
        XCTAssertGreaterThan(bitmap.pixelsHigh, 0)
    }

    func testStatusBarTemplateMissingResourceFallsBack() {
        XCTAssertNil(StatusBarIcon.templateImage(bundle: Bundle(for: ApplicationPresentationTests.self)))
        XCTAssertEqual(StatusBarIcon.fallbackSystemImage, "waveform")
    }
}
