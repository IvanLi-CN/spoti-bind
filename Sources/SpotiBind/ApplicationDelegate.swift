import AppKit

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    private let mediaKeyTapController = MediaKeyTapController()
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        state.onReadinessChanged = { [weak self] in
            self?.mediaKeyTapController.reconcile()
        }
        state.onOpenSettings = { [weak self] in
            self?.showSettingsWindow()
        }
        state.start()
        if !state.isUIDemo {
            mediaKeyTapController.start(state: state)
        }
        UISnapshot.scheduleIfRequested(state: state) { [weak self] in
            self?.showSettingsWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaKeyTapController.stop()
        state.stop()
    }

    private func showSettingsWindow() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(state: state)
        }
        settingsWindowController?.showAndActivate()
    }
}
