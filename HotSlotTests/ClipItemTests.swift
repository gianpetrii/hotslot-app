import XCTest
@testable import HotSlot

final class ClipItemTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let item = ClipItem(
            content: .text("Hola HotSlot"),
            sourceAppName: "Notes",
            sourceAppBundleID: "com.apple.Notes"
        )
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ClipItem.self, from: data)
        XCTAssertEqual(decoded, item)
    }

    func testContentFingerprintTextIsStable() {
        let a = ClipItem(content: .text("mismo texto"))
        let b = ClipItem(content: .text("mismo texto"))
        XCTAssertEqual(a.contentFingerprint, b.contentFingerprint)
        XCTAssertTrue(a.contentFingerprint.hasPrefix("text:"))
    }

    func testContentFingerprintTextDiffers() {
        let a = ClipItem(content: .text("uno"))
        let b = ClipItem(content: .text("dos"))
        XCTAssertNotEqual(a.contentFingerprint, b.contentFingerprint)
    }

    func testPreviewTextTruncation() {
        let long = String(repeating: "a", count: 100)
        let content = ClipContent.text(long)
        XCTAssertTrue(content.previewText.hasSuffix("…"))
    }
}
