import XCTest
@testable import SpotiBindCore

final class PlayerDispatchTests: XCTestCase {
    func testFastpotifyUsesTheFixedCliVerbs() {
        XCTAssertEqual(PlayerDispatch.command(for: .playPause, player: .fastpotify), .fastpotify(.playPause))
        XCTAssertEqual(PlayerDispatch.command(for: .next, player: .fastpotify), .fastpotify(.next))
        XCTAssertEqual(PlayerDispatch.command(for: .previous, player: .fastpotify), .fastpotify(.previous))
    }

    func testSpotiflyUsesSpaceAndCommandArrows() {
        XCTAssertEqual(
            PlayerDispatch.command(for: .playPause, player: .spotifly),
            .keyboard(KeyboardShortcut(keyCode: 49))
        )
        XCTAssertEqual(
            PlayerDispatch.command(for: .next, player: .spotifly),
            .keyboard(KeyboardShortcut(keyCode: 124, modifiers: .command))
        )
        XCTAssertEqual(
            PlayerDispatch.command(for: .previous, player: .spotifly),
            .keyboard(KeyboardShortcut(keyCode: 123, modifiers: .command))
        )
    }

    func testSonoraUsesSpaceAndControlArrows() {
        XCTAssertEqual(
            PlayerDispatch.command(for: .playPause, player: .sonora),
            .keyboard(KeyboardShortcut(keyCode: 49))
        )
        XCTAssertEqual(
            PlayerDispatch.command(for: .next, player: .sonora),
            .keyboard(KeyboardShortcut(keyCode: 124, modifiers: .control))
        )
        XCTAssertEqual(
            PlayerDispatch.command(for: .previous, player: .sonora),
            .keyboard(KeyboardShortcut(keyCode: 123, modifiers: .control))
        )
    }
}
