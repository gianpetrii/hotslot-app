import XCTest
@testable import HotSlot

final class HexColorTests: XCTestCase {
    func testDetectsHexWithAndWithoutHash() {
        XCTAssertEqual(HexColor.normalized("#E2501D"), "#E2501D")
        XCTAssertEqual(HexColor.normalized("e2501d"), "#E2501D")
        XCTAssertEqual(HexColor.normalized("  #e2501d \n"), "#E2501D")
    }

    func testRejectsTextThatIsNotAColor() {
        XCTAssertNil(HexColor.normalized("E2501"))
        XCTAssertNil(HexColor.normalized("#E2501DD"))
        XCTAssertNil(HexColor.normalized("#GGGGGG"))
        XCTAssertNil(HexColor.normalized("hola mundo"))
        XCTAssertNil(HexColor.normalized(""))
    }
}
