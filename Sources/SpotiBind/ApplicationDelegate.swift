import AppKit

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    private let mediaKeyTapController = MediaKeyTapController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        state.start()
        mediaKeyTapController.start(state: state)
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaKeyTapController.stop()
        state.stop()
    }
}
