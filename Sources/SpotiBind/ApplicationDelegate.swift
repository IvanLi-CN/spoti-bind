import AppKit

@MainActor
protocol SettingsWindowPresenting: AnyObject {
    func showAndActivate()
}

typealias SettingsWindowFactory = (
    AppState,
    @escaping () -> Void
) -> any SettingsWindowPresenting

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    let state: AppState
    private let mediaKeyTapController = MediaKeyTapController()
    private let settingsWindowFactory: SettingsWindowFactory
    private let activationPolicySetter: ApplicationPresentationController.PolicySetter
    private lazy var presentationController = ApplicationPresentationController(
        isUIDemo: state.isUIDemo,
        setPolicy: activationPolicySetter
    )
    private var settingsWindowController: (any SettingsWindowPresenting)?
    private var isLaunching = true
    private var isTerminating = false
    private var settingsPresentationRequestedDuringLaunch = false

    override convenience init() {
        self.init(state: AppState())
    }

    init(
        state: AppState = AppState(),
        settingsWindowFactory: SettingsWindowFactory? = nil,
        activationPolicySetter: @escaping ApplicationPresentationController.PolicySetter = {
            NSApplication.shared.setActivationPolicy($0)
        }
    ) {
        self.state = state
        self.settingsWindowFactory = settingsWindowFactory ?? { state, onClose in
            SettingsWindowController(state: state, onClose: onClose)
        }
        self.activationPolicySetter = activationPolicySetter
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        isLaunching = true
        defer {
            isLaunching = false
            if settingsPresentationRequestedDuringLaunch {
                settingsPresentationRequestedDuringLaunch = false
                showSettingsWindow()
            }
        }

        presentationController.configureForLaunch()
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
        isTerminating = true
        mediaKeyTapController.stop()
        state.stop()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showSettingsWindow()
        return true
    }

    private func showSettingsWindow() {
        guard !isTerminating else { return }
        if isLaunching {
            settingsPresentationRequestedDuringLaunch = true
            return
        }

        if settingsWindowController == nil {
            settingsWindowController = settingsWindowFactory(state) { [weak self] in
                self?.presentationController.settingsDidClose()
            }
        }
        presentationController.settingsDidOpen()
        settingsWindowController?.showAndActivate()
    }
}
