import ApplicationServices
import AppKit
import Combine
import SpotiBindCore
import ServiceManagement

@MainActor
final class AppState: ObservableObject {
    @Published var playerMode: PlayerMode
    @Published var launchAtLogin: Bool
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var targetExecutable: FastpotifyExecutable?
    @Published private(set) var probeHealthy = false
    @Published private(set) var tapStatus = "Starting"
    @Published private(set) var dispatchFailure: String?
    var onReadinessChanged: (() -> Void)?

    private let defaults: UserDefaults
    private let locator = FastpotifyExecutableLocator()
    private let catalog = PlayerWorkspaceCatalog()
    private let resolver = PlayerSelectionResolver()
    private let dispatcher: FastpotifyCommandDispatcher
    private let runtime: SystemPlayerRuntime
    private let coordinator: PlayerLaunchCoordinator
    private var availability = PlayerAvailabilitySnapshot()
    private var refreshTimer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var probeTask: Task<Void, Never>?

    init(
        defaults: UserDefaults = .standard,
        dispatcher: FastpotifyCommandDispatcher? = nil
    ) {
        let actualDispatcher = dispatcher ?? FastpotifyCommandDispatcher(runner: SystemProcessRunner())
        self.defaults = defaults
        self.playerMode = PlayerModeMigration.mode(
            storedMode: defaults.string(forKey: Keys.playerMode),
            legacyForwardingEnabled: defaults.object(forKey: Keys.forwardingEnabled) as? Bool
        )
        self.launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        self.dispatcher = actualDispatcher
        self.runtime = SystemPlayerRuntime(dispatcher: actualDispatcher)
        self.coordinator = PlayerLaunchCoordinator(runtime: runtime)
    }

    var readiness: ForwardingReadiness {
        ForwardingReadiness(
            forwardingEnabled: playerMode != .off,
            accessibilityTrusted: accessibilityTrusted,
            targetUsable: resolvedSelection != .none
        )
    }

    private var resolvedSelection: PlayerSelection {
        resolver.resolve(mode: playerMode, snapshot: availability)
    }

    var statusTitle: String {
        if playerMode == .off {
            return "Forwarding disabled"
        }
        if !accessibilityTrusted {
            return "Accessibility permission required"
        }
        switch resolvedSelection {
        case .none:
            return "No supported player found"
        case .launch(let player):
            return "Starting \(player.displayName)"
        case .running(let player):
            if tapStatus != "Ready" {
                return tapStatus
            }
            return "Forwarding to \(player.displayName)"
        }
    }

    var statusDetail: String {
        if let dispatchFailure {
            return dispatchFailure
        }
        switch resolvedSelection {
        case .none:
            return "Install or start a supported player to continue."
        case .launch(let player), .running(let player):
            if player == .fastpotify, let targetExecutable {
                return targetExecutable.url.path
            }
            if let applicationURL = catalog.applicationURL(
                for: player,
                fastpotifyExecutable: targetExecutable
            ) {
                return applicationURL.path
            }
            return player.displayName
        }
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
        updateAvailability()
        onReadinessChanged?()
        probeTarget()
    }

    func setPlayerMode(_ mode: PlayerMode) {
        playerMode = mode
        defaults.set(mode.rawValue, forKey: Keys.playerMode)
        dispatchFailure = nil
        updateAvailability()
        onReadinessChanged?()
        probeTarget()
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

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func setTapStatus(_ status: String) {
        tapStatus = status
    }

    func dispatch(_ key: MediaKey) {
        guard readiness.isReady, let player = resolvedSelection.player else {
            return
        }
        let request = PlayerDispatchRequest(
            selection: resolvedSelection,
            executableURL: player == .fastpotify ? targetExecutable?.url : nil,
            applicationURL: catalog.applicationURL(
                for: player,
                fastpotifyExecutable: targetExecutable
            )
        )
        let coordinator = coordinator
        Task { @MainActor [weak self] in
            let succeeded = await coordinator.dispatch(key, request: request)
            guard let self else { return }
            if succeeded {
                dispatchFailure = nil
            } else {
                dispatchFailure = "\(player.displayName) media-key dispatch failed."
                refreshStatus(promptForAccessibility: false)
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

    private func updateAvailability() {
        availability = catalog.snapshot(
            fastpotifyExecutable: targetExecutable,
            fastpotifyProbeHealthy: probeHealthy
        )
    }

    private func probeTarget() {
        probeTask?.cancel()
        guard playerMode == .automatic || playerMode == .fastpotify else {
            probeHealthy = false
            updateAvailability()
            onReadinessChanged?()
            return
        }
        guard let targetExecutable else {
            probeHealthy = false
            updateAvailability()
            onReadinessChanged?()
            return
        }
        let dispatcher = dispatcher
        let targetURL = targetExecutable.url
        probeTask = Task { @MainActor [weak self] in
            let healthy = await dispatcher.probe(executableURL: targetURL)
            guard !Task.isCancelled, let self else { return }
            self.probeHealthy = healthy
            self.updateAvailability()
            self.onReadinessChanged?()
        }
    }

    private enum Keys {
        static let playerMode = "playerMode"
        static let forwardingEnabled = "forwardingEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let targetPath = "targetPath"
    }
}
