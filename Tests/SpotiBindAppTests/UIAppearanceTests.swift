import XCTest
@testable import SpotiBind

final class UIAppearanceTests: XCTestCase {
    func testLightAndDarkMapToStableAppKitAppearances() {
        XCTAssertEqual(UIAppearance.parse(environment: ["SPOTIBIND_UI_APPEARANCE": "light"]), .light)
        XCTAssertEqual(UIAppearance.parse(environment: ["SPOTIBIND_UI_APPEARANCE": "dark"]), .dark)
        XCTAssertEqual(UIAppearance.light.nsAppearance, .aqua)
        XCTAssertEqual(UIAppearance.dark.nsAppearance, .darkAqua)
    }

    func testMissingAppearanceDefaultsToLightAndUnknownIsRejected() {
        XCTAssertEqual(UIAppearance.parse(environment: [:]), .light)
        XCTAssertNil(UIAppearance.parse(environment: ["SPOTIBIND_UI_APPEARANCE": "system"]))
    }
}
