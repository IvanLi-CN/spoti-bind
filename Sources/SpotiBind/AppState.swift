import ApplicationServices
import AppKit
import Combine
import SpotiBindCore
import ServiceManagement
import UniformTypeIdentifiers

enum PlayerPathState: Equatable {
    case automatic
    case inheritedLegacy(URL?)
    case custom(URL, valid: Bool)

    var path: String? {
        switch self {
        case .automatic:
            nil
        case .inheritedLegacy(let url):
            url?.path
        case .custom(let url, _):
            url.path
        }
    }

    var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }
}

typealias StatusAction = RoutingStatusAction

@MainActor
final class AppState: ObservableObject {
    @Published var playerMode: PlayerMode
    @Published var launchAtLogin: Bool
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var targetExecutable: FastpotifyExecutable?
    @Published private(set) var probeHealthy = false
    @Published private(set) var tapStatus = "Starting"
    @Published private(set) var dispatchFailure: String?
    @Published private(set) var pathSettings: PlayerPathSettings
    @Published private(set) var pathStates: [SupportedPlayer: PlayerPathState] = [:]
    @Published private(set) var pathProblems: [SupportedPlayer: String] = [:]
    @Published private(set) var isDispatching = false

    var onReadinessChanged: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    private let defaults: UserDefaults
    private let locator = FastpotifyExecutableLocator()
    private let catalog = PlayerWorkspaceCatalog()
    private let resolver = PlayerSelectionResolver()
    private let dispatcher: FastpotifyCommandDispatcher
    private let runtime: SystemPlayerRuntime
    private let coordinator: PlayerLaunchCoordinator
    private let demoRequested: Bool
    private let demoConfiguration: UIDemoConfiguration?
    private var availability = PlayerAvailabilitySnapshot()
    private var applicationOverrides: [SupportedPlayer: URL] = [:]
    private var invalidPathPlayers: Set<SupportedPlayer> = []
    private var refreshTimer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var probeTask: Task<Void, Never>?
    private var pendingDispatches = 0

    init(
        defaults: UserDefaults? = nil,
        dispatcher: FastpotifyCommandDispatcher? = nil
    ) {
        let demoConfiguration = UIDemoConfiguration.parse(
            environment: ProcessInfo.processInfo.environment
        )
        self.demoRequested = ProcessInfo.processInfo.environment["SPOTIBIND_UI_DEMO"] == "1"
        self.demoConfiguration = demoConfiguration
        let configuredDefaults = defaults ?? (demoRequested ? UserDefaults() : .standard)
        let actualDispatcher = dispatcher ?? FastpotifyCommandDispatcher(runner: SystemProcessRunner())
        self.defaults = configuredDefaults
        self.playerMode = PlayerModeMigration.mode(
            storedMode: demoConfiguration?.playerMode.rawValue
                ?? configuredDefaults.string(forKey: Keys.playerMode),
            legacyForwardingEnabled: !demoRequested
                ? configuredDefaults.object(forKey: Keys.forwardingEnabled) as? Bool
                : nil
        )
        self.launchAtLogin = !demoRequested
            ? configuredDefaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
            : false
        self.pathSettings = demoConfiguration?.pathSettings
            ?? Self.loadPathSettings(from: configuredDefaults)
        self.dispatcher = actualDispatcher
        self.runtime = SystemPlayerRuntime(dispatcher: actualDispatcher)
        self.coordinator = PlayerLaunchCoordinator(runtime: runtime)
        self.accessibilityTrusted = demoConfiguration?.accessibilityTrusted ?? false
        self.probeHealthy = demoConfiguration?.probeHealthy ?? false
        self.tapStatus = demoConfiguration?.tapStatus ?? "Starting"
        self.dispatchFailure = demoConfiguration?.dispatchFailure
        self.pathStates = demoConfiguration?.pathStates ?? [:]
        self.pathProblems = demoConfiguration?.pathProblems ?? [:]
        self.availability = demoConfiguration?.availability ?? PlayerAvailabilitySnapshot()
    }

    var isUIDemo: Bool {
        demoRequested
    }

    var uiDemoConfiguration: UIDemoConfiguration? {
        demoConfiguration
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
        routingPresentation.title
    }

    var statusDetail: String {
        routingPresentation.detail
    }

    var statusAction: StatusAction? {
        routingPresentation.action
    }

    var statusActionTitle: String? {
        switch statusAction {
        case .accessibility:
            "Open Accessibility Settings"
        case .settings:
            "Review Settings"
        case nil:
            nil
        }
    }

    func performStatusAction() {
        switch statusAction {
        case .accessibility:
            openAccessibilitySettings()
        case .settings:
            openAdvancedSettings()
        case nil:
            break
        }
    }

    func start() {
        guard !demoRequested else {
            onReadinessChanged?()
            return
        }
        refreshStatus(promptForAccessibility: false)
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
        guard !demoRequested else { return }
        let options: CFDictionary? = promptForAccessibility
            ? ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            : nil
        accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
        resolveTargets()
        updateAvailability()
        onReadinessChanged?()
        probeTarget()
    }

    func requestAccessibilityPermission() {
        guard !demoRequested else { return }
        refreshStatus(promptForAccessibility: true)
    }

    func setPlayerMode(_ mode: PlayerMode) {
        if demoRequested {
            playerMode = mode
            dispatchFailure = nil
            return
        }
        let changed = playerMode != mode
        playerMode = mode
        defaults.set(mode.rawValue, forKey: Keys.playerMode)
        dispatchFailure = nil
        updateAvailability()
        onReadinessChanged?()
        if changed, mode != .off {
            requestAccessibilityPermission()
        } else {
            probeTarget()
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard !demoRequested else { return }
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
        guard !demoRequested else { return }
        let currentSettingsURL = URL(
            string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        )!
        let legacySettingsURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!

        if !NSWorkspace.shared.open(currentSettingsURL) {
            NSWorkspace.shared.open(legacySettingsURL)
        }
    }

    func openAdvancedSettings() {
        onOpenSettings?()
    }

    func setTapStatus(_ status: String) {
        tapStatus = status
    }

    func dispatchFromMenu(_ key: MediaKey) {
        guard !demoRequested else { return }
        guard accessibilityTrusted else {
            requestAccessibilityPermission()
            return
        }
        dispatch(key)
    }

    func dispatch(_ key: MediaKey) {
        guard !demoRequested else { return }
        updateAvailability()
        let selection = resolvedSelection
        guard readiness.isReady, let player = selection.player else {
            return
        }
        let request = PlayerDispatchRequest(
            selection: selection,
            executableURL: player == .fastpotify ? targetExecutable?.url : nil,
            applicationURL: applicationURL(for: player)
        )
        pendingDispatches += 1
        isDispatching = true
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
            pendingDispatches = max(0, pendingDispatches - 1)
            isDispatching = pendingDispatches > 0
        }
    }

    func pathState(for player: SupportedPlayer) -> PlayerPathState {
        pathStates[player] ?? .automatic
    }

    func pathDisplay(for player: SupportedPlayer) -> String {
        if let path = pathState(for: player).path {
            return path
        }
        if let applicationURL = applicationURL(for: player) {
            return applicationURL.path
        }
        return "Automatic discovery"
    }

    func choosePath(for player: SupportedPlayer) {
        guard !demoRequested else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = player == .fastpotify
        if player != .fastpotify {
            panel.allowedContentTypes = [.applicationBundle]
        }
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard player == .fastpotify || isValidApplication(url, for: player) else {
            pathProblems[player] = "Selected item is not the expected \(player.displayName) application."
            pathStates[player] = .custom(url, valid: false)
            return
        }

        var updated = pathSettings
        updated.set(.custom(url), for: player)
        pathSettings = updated
        persistPathSettings()
        dispatchFailure = nil
        refreshStatus(promptForAccessibility: false)
    }

    func resetPath(for player: SupportedPlayer) {
        guard !demoRequested else { return }
        var updated = pathSettings
        updated.set(.automatic, for: player)
        pathSettings = updated
        persistPathSettings()
        dispatchFailure = nil
        refreshStatus(promptForAccessibility: false)
    }

    private func resolveTargets() {
        pathProblems = [:]
        applicationOverrides = [:]
        invalidPathPlayers = []

        let previousTarget = targetExecutable?.url
        let fastConfiguration = pathSettings.configuration(for: .fastpotify)
        switch fastConfiguration {
        case .automatic:
            targetExecutable = locator.locateAutomatically()
            pathStates[.fastpotify] = .automatic
        case .inheritLegacy:
            let legacyURL = defaults.string(forKey: Keys.targetPath).map(URL.init(fileURLWithPath:))
            pathStates[.fastpotify] = .inheritedLegacy(legacyURL)
            if let legacyURL {
                targetExecutable = locator.locate(userSelectedURL: legacyURL)
                if targetExecutable == nil {
                    pathProblems[.fastpotify] = "The saved Fastpotify path is unavailable. Choose a new path or reset it."
                    invalidPathPlayers.insert(.fastpotify)
                }
            } else {
                targetExecutable = locator.locateAutomatically()
            }
        case .custom(let url):
            pathStates[.fastpotify] = .custom(url, valid: false)
            targetExecutable = locator.locate(userSelectedURL: url)
            if targetExecutable == nil {
                pathProblems[.fastpotify] = "The custom Fastpotify path is unavailable. Choose a new path or reset it."
                invalidPathPlayers.insert(.fastpotify)
            } else {
                pathStates[.fastpotify] = .custom(url, valid: true)
            }
        }

        for player in [SupportedPlayer.spotify, .sonora, .spotifly] {
            switch pathSettings.configuration(for: player) {
            case .automatic, .inheritLegacy:
                pathStates[player] = .automatic
            case .custom(let url):
                pathStates[player] = .custom(url, valid: false)
                guard isValidApplication(url, for: player) else {
                    pathProblems[player] = "The custom \(player.displayName) path is unavailable. Choose a new path or reset it."
                    invalidPathPlayers.insert(player)
                    continue
                }
                pathStates[player] = .custom(url, valid: true)
                applicationOverrides[player] = url
            }
        }

        if previousTarget != targetExecutable?.url {
            probeHealthy = false
            dispatchFailure = nil
        }
    }

    private func updateAvailability() {
        availability = catalog.snapshot(
            fastpotifyExecutable: targetExecutable,
            fastpotifyProbeHealthy: probeHealthy,
            customApplicationURLs: applicationOverrides,
            invalidCustomPlayers: invalidPathPlayers
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

    func applicationURL(for player: SupportedPlayer) -> URL? {
        if demoRequested {
            return URL(fileURLWithPath: "/Demo/Applications/\(player.displayName).app")
        }
        return catalog.applicationURL(
            for: player,
            fastpotifyExecutable: targetExecutable,
            customApplicationURLs: applicationOverrides
        )
    }

    private var routingPresentation: RoutingPresentation {
        let issue: RoutingIssue?
        if let player = pathProblems.keys.sorted(by: { $0.rawValue < $1.rawValue }).first,
           let detail = pathProblems[player] {
            issue = .pathUnavailable(player: player, detail: detail)
        } else if let dispatchFailure {
            issue = .dispatchFailure(detail: dispatchFailure)
        } else {
            issue = nil
        }
        let targetDetail = resolvedSelection.player.map(pathDisplay(for:)) ?? ""
        return RoutingPresentation.make(
            mode: playerMode,
            accessibilityTrusted: accessibilityTrusted,
            issue: issue,
            selection: resolvedSelection,
            tapStatus: tapStatus,
            targetDetail: targetDetail
        )
    }

    private func isValidApplication(_ url: URL, for player: SupportedPlayer) -> Bool {
        guard url.pathExtension.caseInsensitiveCompare("app") == .orderedSame,
              FileManager.default.fileExists(atPath: url.path),
              let bundle = Bundle(url: url) else {
            return false
        }
        return bundle.bundleIdentifier == player.bundleIdentifier
    }

    private func persistPathSettings() {
        guard let data = try? JSONEncoder().encode(pathSettings) else { return }
        defaults.set(data, forKey: Keys.pathSettings)
    }

    private static func loadPathSettings(from defaults: UserDefaults) -> PlayerPathSettings {
        guard let data = defaults.data(forKey: Keys.pathSettings),
              let settings = try? JSONDecoder().decode(PlayerPathSettings.self, from: data) else {
            return PlayerPathSettings()
        }
        return settings
    }

    private enum Keys {
        static let playerMode = "playerMode"
        static let forwardingEnabled = "forwardingEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let targetPath = "targetPath"
        static let pathSettings = "playerPathSettings"
    }
}
