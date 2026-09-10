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
}
