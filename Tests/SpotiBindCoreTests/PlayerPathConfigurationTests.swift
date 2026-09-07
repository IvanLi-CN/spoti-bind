import Foundation
import XCTest
@testable import SpotiBindCore

final class PlayerPathConfigurationTests: XCTestCase {
    func testMissingFastpotifyConfigurationInheritsLegacyPath() {
        let settings = PlayerPathSettings()

        XCTAssertEqual(settings.configuration(for: .fastpotify), .inheritLegacy)
        XCTAssertEqual(settings.configuration(for: .sonora), .automatic)
    }

    func testResetIsStoredAsExplicitAutomaticConfiguration() throws {
        var settings = PlayerPathSettings()
        settings.set(.custom(URL(fileURLWithPath: "/Applications/Fastpotify.app")), for: .fastpotify)
        settings.set(.automatic, for: .fastpotify)

        let data = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(PlayerPathSettings.self, from: data)

        XCTAssertEqual(restored.configuration(for: .fastpotify), .automatic)
    }

    func testSettingsRoundTripPreservesEveryCustomPlayerPath() throws {
        let paths: [SupportedPlayer: PlayerPathConfiguration] = [
            .fastpotify: .custom(URL(fileURLWithPath: "/Applications/Fastpotify.app")),
            .sonora: .custom(URL(fileURLWithPath: "/Applications/Sonora.app")),
            .spotifly: .custom(URL(fileURLWithPath: "/Applications/Spotifly.app"))
        ]
        let settings = PlayerPathSettings(values: paths)

        let data = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(PlayerPathSettings.self, from: data)

        XCTAssertEqual(restored, settings)
    }

    func testInvalidSelectedPathDoesNotFallBackToKnownLocation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpotiBindPathTests-\(UUID().uuidString)")
        let invalidApp = root.appendingPathComponent("Fastpotify.app")
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        XCTAssertNil(FastpotifyExecutableLocator().locate(userSelectedURL: invalidApp))
    }
}
