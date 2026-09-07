import ApplicationServices
import AppKit
import Combine
import SpotiBindCore
import ServiceManagement

@MainActor
final class AppState: ObservableObject {
    @Published var forwardingEnabled: Bool
    @Published var launchAtLogin: Bool
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var targetExecutable: FastpotifyExecutable?
    @Published private(set) var probeHealthy = false
    @Published private(set) var tapStatus = "Starting"
    @Published private(set) var dispatchFailure: String?

    private let defaults: UserDefaults
    private let locator = FastpotifyExecutableLocator()
    private let dispatcher: FastpotifyCommandDispatcher
    private var refreshTimer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var probeTask: Task<Void, Never>?

    init(
        defaults: UserDefaults = .standard,
        dispatcher: FastpotifyCommandDispatcher? = nil
    ) {
        self.defaults = defaults
        self.forwardingEnabled = defaults.object(forKey: Keys.forwardingEnabled) as? Bool ?? true
        self.launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        self.dispatcher = dispatcher ?? FastpotifyCommandDispatcher(runner: SystemProcessRunner())
    }

    var readiness: ForwardingReadiness {
        ForwardingReadiness(
            forwardingEnabled: forwardingEnabled,
            accessibilityTrusted: accessibilityTrusted,
            targetUsable: targetExecutable != nil,
            probeHealthy: probeHealthy
        )
    }

    var statusTitle: String {
        if !forwardingEnabled {
            return "Forwarding disabled"
        }
        if !accessibilityTrusted {
            return "Accessibility permission required"
        }
        if targetExecutable == nil {
            return "Fastpotify not found"
        }
        if !probeHealthy {
            return "Fastpotify is not ready"
        }
        if tapStatus != "Ready" {
            return tapStatus
        }
        return "Forwarding to Fastpotify"
    }

    var statusDetail: String {
        if let dispatchFailure {
            return dispatchFailure
        }
        if let targetExecutable {
            return targetExecutable.url.path
        }
        return "Choose a Fastpotify app or executable to continue."
    }

    func start() {
        refreshStatus(promptForAccessibility: true)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshStatus(promptForAccessibility: false)
            }
        }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshStatus(promptForAccessibility: false)
            }
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        probeTask?.cancel()
        probeTask = nil
    }

    func refreshStatus(promptForAccessibility: Bool) {
        let options: CFDictionary? = promptForAccessibility
            ? ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            : nil
        accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
        resolveTarget()
        probeTarget()
    }

    func setForwardingEnabled(_ enabled: Bool) {
        forwardingEnabled = enabled
        defaults.set(enabled, forKey: Keys.forwardingEnabled)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
            defaults.set(enabled, forKey: Keys.launchAtLogin)
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            dispatchFailure = "Login item update failed: \(error.localizedDescription)"
        }
    }

    func chooseTarget() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose the Fastpotify app or executable"
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        defaults.set(url.path, forKey: Keys.targetPath)
        resolveTarget()
        probeTarget()
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func setTapStatus(_ status: String) {
        tapStatus = status
    }

    func dispatch(_ command: FastpotifyCommand) {
        guard let executable = targetExecutable else {
            return
        }
        let dispatcher = dispatcher
        let targetURL = executable.url
        probeHealthy = true
        Task { @MainActor [weak self] in
            let result = await dispatcher.dispatch(command, executableURL: targetURL)
            guard let self else { return }
            if result.succeeded {
                self.dispatchFailure = nil
            } else {
                self.dispatchFailure = result.timedOut
                    ? "Fastpotify command timed out."
                    : "Fastpotify command failed."
                self.probeHealthy = false
            }
        }
    }

    private func resolveTarget() {
        let selectedPath = defaults.string(forKey: Keys.targetPath).map(URL.init(fileURLWithPath:))
        let resolvedTarget = locator.locate(userSelectedURL: selectedPath)
        if resolvedTarget?.url != targetExecutable?.url {
            probeHealthy = false
            dispatchFailure = nil
        }
        targetExecutable = resolvedTarget
    }

    private func probeTarget() {
        probeTask?.cancel()
        guard let targetExecutable else {
            probeHealthy = false
            return
        }
        let dispatcher = dispatcher
        let targetURL = targetExecutable.url
        probeTask = Task { @MainActor [weak self] in
            let healthy = await dispatcher.probe(executableURL: targetURL)
            guard !Task.isCancelled, let self else { return }
            self.probeHealthy = healthy
        }
    }

    private enum Keys {
        static let forwardingEnabled = "forwardingEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let targetPath = "targetPath"
    }
}
