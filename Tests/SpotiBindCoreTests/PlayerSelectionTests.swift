import XCTest
@testable import SpotiBindCore

final class PlayerSelectionTests: XCTestCase {
    private let resolver = PlayerSelectionResolver()

    func testAutomaticPrefersRunningPlayersInStableProductOrder() {
        let snapshot = PlayerAvailabilitySnapshot([
            availability(.spotifly, installed: true, running: true, launchable: true),
            availability(.sonora, installed: true, running: true, launchable: true),
            availability(.fastpotify, installed: true, running: true, launchable: true)
        ])

        XCTAssertEqual(resolver.resolve(mode: .automatic, snapshot: snapshot), .running(.fastpotify))
    }

    func testAutomaticStartsFirstInstalledPlayerWhenNoneAreRunning() {
        let snapshot = PlayerAvailabilitySnapshot([
            availability(.spotifly, installed: true, running: false, launchable: true),
            availability(.sonora, installed: true, running: false, launchable: true)
        ])

        XCTAssertEqual(resolver.resolve(mode: .automatic, snapshot: snapshot), .launch(.sonora))
    }

    func testAutomaticSkipsUninstalledPlayers() {
        let snapshot = PlayerAvailabilitySnapshot([
            availability(.fastpotify, installed: false, running: false, launchable: false),
            availability(.sonora, installed: false, running: false, launchable: false),
            availability(.spotifly, installed: true, running: false, launchable: true)
        ])

        XCTAssertEqual(resolver.resolve(mode: .automatic, snapshot: snapshot), .launch(.spotifly))
    }

    func testManualModeOnlySelectsTheRequestedPlayer() {
        let snapshot = PlayerAvailabilitySnapshot([
            availability(.fastpotify, installed: true, running: true, launchable: true),
            availability(.sonora, installed: true, running: false, launchable: true)
        ])

        XCTAssertEqual(resolver.resolve(mode: .sonora, snapshot: snapshot), .launch(.sonora))
        XCTAssertEqual(resolver.resolve(mode: .spotifly, snapshot: snapshot), .none)
    }

    func testOffModeAndNoTargetsResolveToNone() {
        let empty = PlayerAvailabilitySnapshot()
        XCTAssertEqual(resolver.resolve(mode: .off, snapshot: empty), .none)
        XCTAssertEqual(resolver.resolve(mode: .automatic, snapshot: empty), .none)
    }

    func testTrayResidentSonoraIsReopenedBeforePIDShortcutRouting() {
        let snapshot = PlayerAvailabilitySnapshot([
            availability(.sonora, installed: true, running: true, launchable: true, requiresLaunch: true)
        ])

        XCTAssertEqual(resolver.resolve(mode: .sonora, snapshot: snapshot), .launch(.sonora))
        XCTAssertEqual(resolver.resolve(mode: .automatic, snapshot: snapshot), .launch(.sonora))
    }

    func testAutomaticReopensTrayResidentSonoraBeforeLaterRunningPlayer() {
        let snapshot = PlayerAvailabilitySnapshot([
            availability(.sonora, installed: true, running: true, launchable: true, requiresLaunch: true),
            availability(.spotifly, installed: true, running: true, launchable: true)
        ])

        XCTAssertEqual(resolver.resolve(mode: .automatic, snapshot: snapshot), .launch(.sonora))
    }

    func testLegacyDisabledPreferenceMigratesToOffAndMissingPreferenceToAutomatic() {
        XCTAssertEqual(PlayerModeMigration.mode(storedMode: nil, legacyForwardingEnabled: false), .off)
        XCTAssertEqual(PlayerModeMigration.mode(storedMode: nil, legacyForwardingEnabled: true), .automatic)
        XCTAssertEqual(PlayerModeMigration.mode(storedMode: nil, legacyForwardingEnabled: nil), .automatic)
        XCTAssertEqual(PlayerModeMigration.mode(storedMode: PlayerMode.sonora.rawValue, legacyForwardingEnabled: false), .sonora)
    }

    private func availability(
        _ player: SupportedPlayer,
        installed: Bool,
        running: Bool,
        launchable: Bool,
        requiresLaunch: Bool = false
    ) -> PlayerAvailability {
        PlayerAvailability(
            player: player,
            isInstalled: installed,
            isRunning: running,
            canLaunch: launchable,
            requiresLaunch: requiresLaunch
        )
    }
}
