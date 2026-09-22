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

    func testContentFingerprintText() {
        let item = ClipItem(content: .text("mismo texto"))
        XCTAssertEqual(item.contentFingerprint, "text:mismo texto")
    }

    func testContentFingerprintImage() {
        let item = ClipItem(content: .image(fileName: "abc.png"))
        XCTAssertEqual(item.contentFingerprint, "image:abc.png")
    }

    func testPreviewTextTruncation() {
        let long = String(repeating: "a", count: 100)
        let content = ClipContent.text(long)
        XCTAssertTrue(content.previewText.hasSuffix("…"))
    }
}
