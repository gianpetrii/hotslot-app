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

    func testImageTypeLabelIsSpanish() {
        let content = ClipContent.image(fileName: "abc.png")
        XCTAssertEqual(content.typeLabel, "Imagen PNG")
        let item = ClipItem(content: content)
        XCTAssertTrue(item.metadataLine().hasPrefix("Imagen PNG · "))
    }

    func testTextTypeLabelIsSpanish() {
        let content = ClipContent.text("hola")
        XCTAssertEqual(content.typeLabel, "Texto")
    }
}
