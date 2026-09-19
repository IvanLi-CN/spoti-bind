import AppKit
import XCTest
@testable import SpotiBind

@MainActor
final class ApplicationDelegateTests: XCTestCase {
    func testProductionInitializerIsAvailable() {
        _ = ApplicationDelegate()
    }

    func testReopenRequestAlwaysPresentsSettings() {
        let presenter = RecordingSettingsPresenter()
        let delegate = ApplicationDelegate(
            state: AppState(environment: ["SPOTIBIND_UI_DEMO": "0"]),
            settingsWindowFactory: { _, _ in presenter },
            activationPolicySetter: { _ in true }
        )
        finishLaunching(delegate)

        XCTAssertTrue(
            delegate.applicationShouldHandleReopen(
                NSApplication.shared,
                hasVisibleWindows: false
            )
        )
        XCTAssertTrue(
            delegate.applicationShouldHandleReopen(
                NSApplication.shared,
                hasVisibleWindows: true
            )
        )

        XCTAssertEqual(presenter.showAndActivateCallCount, 2)
    }

    func testReopenRequestReusesOneSettingsPresenter() {
        let presenter = RecordingSettingsPresenter()
        var factoryCallCount = 0
        let delegate = ApplicationDelegate(
            state: AppState(environment: ["SPOTIBIND_UI_DEMO": "0"]),
            settingsWindowFactory: { _, _ in
                factoryCallCount += 1
                return presenter
            },
            activationPolicySetter: { _ in true }
        )
        finishLaunching(delegate)

        _ = delegate.applicationShouldHandleReopen(
            NSApplication.shared,
            hasVisibleWindows: false
        )
        _ = delegate.applicationShouldHandleReopen(
            NSApplication.shared,
            hasVisibleWindows: false
        )

        XCTAssertEqual(factoryCallCount, 1)
        XCTAssertEqual(presenter.showAndActivateCallCount, 2)
    }

    func testReopenBeforeLaunchCompletesAfterLaunchSetup() {
        var policies: [NSApplication.ActivationPolicy] = []
        let presenter = RecordingSettingsPresenter()
        let delegate = ApplicationDelegate(
            state: AppState(environment: ["SPOTIBIND_UI_DEMO": "0"]),
            settingsWindowFactory: { _, _ in presenter },
            activationPolicySetter: { policy in
                policies.append(policy)
                return true
            }
        )

        XCTAssertTrue(
            delegate.applicationShouldHandleReopen(
                NSApplication.shared,
                hasVisibleWindows: false
            )
        )
        XCTAssertEqual(presenter.showAndActivateCallCount, 0)

        finishLaunching(delegate)

        XCTAssertEqual(presenter.showAndActivateCallCount, 1)
        XCTAssertEqual(policies, [.accessory, .regular])
    }

    func testReopenRequestDuringTerminationDoesNotCreateSettingsPresenter() {
        let delegate = ApplicationDelegate(
            state: AppState(environment: ["SPOTIBIND_UI_DEMO": "1"]),
            settingsWindowFactory: { _, _ in
                XCTFail("Settings presenter must not be created during termination")
                return RecordingSettingsPresenter()
            }
        )

        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))

        XCTAssertTrue(
            delegate.applicationShouldHandleReopen(
                NSApplication.shared,
                hasVisibleWindows: false
            )
        )
    }
}

@MainActor
private func finishLaunching(_ delegate: ApplicationDelegate) {
    delegate.applicationDidFinishLaunching(
        Notification(name: NSApplication.didFinishLaunchingNotification)
    )
}

@MainActor
private final class RecordingSettingsPresenter: SettingsWindowPresenting {
    private(set) var showAndActivateCallCount = 0

    func showAndActivate() {
        showAndActivateCallCount += 1
    }
}
