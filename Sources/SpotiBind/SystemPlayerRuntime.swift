@preconcurrency import AppKit
@preconcurrency import CoreGraphics
import SpotiBindCore

final class SystemPlayerRuntime: PlayerLaunchRuntime, @unchecked Sendable {
    private let dispatcher: FastpotifyCommandDispatcher

    init(dispatcher: FastpotifyCommandDispatcher) {
        self.dispatcher = dispatcher
    }

    func launch(player: SupportedPlayer, applicationURL: URL?) async -> Bool {
        let url = await MainActor.run {
            applicationURL ?? self.applicationURL(for: player)
        }
        guard let url else { return false }

        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                let configuration = NSWorkspace.OpenConfiguration()
                // Sonora only installs its keyboard shortcut context while a
                // main window is present. Reopening a tray-resident instance
                // restores that input surface before dispatch.
                configuration.activates = false
                if player == .sonora {
                    configuration.activates = true
                }
                NSWorkspace.shared.openApplication(at: url, configuration: configuration) { application, error in
                    continuation.resume(returning: application != nil && error == nil)
                }
            }
        }
    }

    func isRunning(player: SupportedPlayer, applicationURL: URL?) async -> Bool {
        await MainActor.run {
            guard let application = runningApplication(for: player, applicationURL: applicationURL) else {
                return false
            }
            return acceptsKeyboardInput(for: player, application: application)
        }
    }

    func dispatch(
        key: MediaKey,
        player: SupportedPlayer,
        executableURL: URL?,
        applicationURL: URL?
    ) async -> Bool {
        switch PlayerDispatch.command(for: key, player: player) {
        case .fastpotify(let command):
            guard let executableURL else { return false }
            return (await dispatcher.dispatch(command, executableURL: executableURL)).succeeded
        case .keyboard(let shortcut):
            return await MainActor.run {
                guard let application = runningApplication(for: player, applicationURL: applicationURL) else {
                    return false
                }
                guard acceptsKeyboardInput(for: player, application: application) else {
                    return false
                }
                return post(shortcut, to: application.processIdentifier)
            }
        }
    }

    @MainActor
    private func applicationURL(for player: SupportedPlayer) -> URL? {
        guard let bundleIdentifier = player.bundleIdentifier else { return nil }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    @MainActor
    private func runningApplication(
        for player: SupportedPlayer,
        applicationURL: URL?
    ) -> NSRunningApplication? {
        let applications = NSWorkspace.shared.runningApplications
        if let applicationURL {
            let expectedPath = applicationURL.standardizedFileURL.path
            return applications.first(where: {
                $0.bundleURL?.standardizedFileURL.path == expectedPath
            })
        }
        if let bundleIdentifier = player.bundleIdentifier {
            return applications.first { $0.bundleIdentifier == bundleIdentifier }
        }

        return applications.first {
            $0.localizedName?.localizedCaseInsensitiveCompare(player.displayName) == .orderedSame
        }
    }

    @MainActor
    private func acceptsKeyboardInput(
        for player: SupportedPlayer,
        application: NSRunningApplication
    ) -> Bool {
        guard player == .sonora else { return true }
        return application.activationPolicy == .regular
    }

    @MainActor
    private func post(_ shortcut: KeyboardShortcut, to pid: pid_t) -> Bool {
        var flags = CGEventFlags()
        if shortcut.modifiers.contains(.command) {
            flags.insert(.maskCommand)
        }
        if shortcut.modifiers.contains(.control) {
            flags.insert(.maskControl)
        }

        guard let keyDown = CGEvent(
            keyboardEventSource: nil,
            virtualKey: shortcut.keyCode,
            keyDown: true
        ), let keyUp = CGEvent(
            keyboardEventSource: nil,
            virtualKey: shortcut.keyCode,
            keyDown: false
        ) else {
            return false
        }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.postToPid(pid)
        keyUp.postToPid(pid)
        return true
    }
}

@MainActor
final class PlayerWorkspaceCatalog {
    func snapshot(
        fastpotifyExecutable: FastpotifyExecutable?,
        fastpotifyProbeHealthy: Bool,
        customApplicationURLs: [SupportedPlayer: URL] = [:],
        invalidCustomPlayers: Set<SupportedPlayer> = []
    ) -> PlayerAvailabilitySnapshot {
        var values: [PlayerAvailability] = []
        let fastpotifyApplicationURL = fastpotifyExecutable?.applicationURL
        let fastpotifyRunning = fastpotifyProbeHealthy || runningFastpotify(applicationURL: fastpotifyApplicationURL)
        values.append(
            PlayerAvailability(
                player: .fastpotify,
                isInstalled: fastpotifyExecutable != nil,
                isRunning: fastpotifyRunning,
                canLaunch: fastpotifyApplicationURL != nil
            )
        )

        for player in [SupportedPlayer.spotify, .sonora, .spotifly] {
            if invalidCustomPlayers.contains(player) {
                values.append(
                    PlayerAvailability(
                        player: player,
                        isInstalled: false,
                        isRunning: false,
                        canLaunch: false
                    )
                )
                continue
            }
            let applicationURL = customApplicationURLs[player] ?? applicationURL(for: player)
            let application = runningApplication(for: player, applicationURL: applicationURL)
            let requiresLaunch = player == .sonora && application?.activationPolicy != .regular
            // A tray-resident Sonora needs a workspace reopen to restore its
            // main-window shortcut context, so it remains launchable.
            let canLaunch = applicationURL != nil
            values.append(
                PlayerAvailability(
                    player: player,
                    isInstalled: applicationURL != nil,
                    isRunning: application != nil,
                    canLaunch: canLaunch,
                    requiresLaunch: requiresLaunch
                )
            )
        }

        return PlayerAvailabilitySnapshot(values)
    }

    func applicationURL(
        for player: SupportedPlayer,
        fastpotifyExecutable: FastpotifyExecutable?,
        customApplicationURLs: [SupportedPlayer: URL] = [:]
    ) -> URL? {
        if player == .fastpotify {
            return fastpotifyExecutable?.applicationURL
        }
        return customApplicationURLs[player] ?? applicationURL(for: player)
    }

    private func applicationURL(for player: SupportedPlayer) -> URL? {
        guard let bundleIdentifier = player.bundleIdentifier else { return nil }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    private func runningFastpotify(applicationURL: URL?) -> Bool {
        let applications = NSWorkspace.shared.runningApplications
        if let applicationURL {
            let expectedPath = applicationURL.standardizedFileURL.path
            return applications.contains { $0.bundleURL?.standardizedFileURL.path == expectedPath }
        }
        return applications.contains {
            $0.localizedName?.localizedCaseInsensitiveCompare(SupportedPlayer.fastpotify.displayName) == .orderedSame
        }
    }

    private func runningApplication(
        for player: SupportedPlayer,
        applicationURL: URL?
    ) -> NSRunningApplication? {
        if let applicationURL {
            let expectedPath = applicationURL.standardizedFileURL.path
            return NSWorkspace.shared.runningApplications.first(where: {
                $0.bundleURL?.standardizedFileURL.path == expectedPath
            })
        }
        guard let bundleIdentifier = player.bundleIdentifier else { return nil }
        return NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleIdentifier }
    }
}
