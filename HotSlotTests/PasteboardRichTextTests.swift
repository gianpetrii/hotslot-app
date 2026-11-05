import AppKit
import XCTest
@testable import HotSlot

final class PasteboardRichTextTests: XCTestCase {
    private var tempDir: URL!
    private var source: NSPasteboard!
    private var target: NSPasteboard!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HotSlotTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        AppSupportDirectory.rootOverride = tempDir
        source = NSPasteboard(name: .init("HotSlotTests-source-\(UUID().uuidString)"))
        target = NSPasteboard(name: .init("HotSlotTests-target-\(UUID().uuidString)"))
    }

    override func tearDown() {
        source.releaseGlobally()
        target.releaseGlobally()
        AppSupportDirectory.rootOverride = nil
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testRichTextAndLineBreaksSurviveCopyAndPaste() throws {
        let plain = "Título\nsegunda línea"
        let styled = NSMutableAttributedString(string: plain)
        styled.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 13), range: NSRange(location: 0, length: 6))
        let rtf = try XCTUnwrap(styled.rtf(from: NSRange(location: 0, length: styled.length)))

        source.clearContents()
        source.setData(rtf, forType: .rtf)
        source.setString(plain, forType: .string)

        let content = try XCTUnwrap(PasteboardHelper.readContent(from: source))
        XCTAssertEqual(content, .text(plain))

        PasteboardHelper.write(content: content, to: target)
        XCTAssertEqual(target.string(forType: .string), plain)
        let pastedRTF = try XCTUnwrap(target.data(forType: .rtf))
        let pasted = try XCTUnwrap(NSAttributedString(rtf: pastedRTF, documentAttributes: nil))
        let font = pasted.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.bold) ?? false)
    }

    func testPlainCopyOfSameTextDropsOldFormatting() throws {
        let plain = "mismo texto"
        let rtf = try XCTUnwrap(NSAttributedString(string: plain).rtf(from: NSRange(location: 0, length: 11)))
        source.clearContents()
        source.setData(rtf, forType: .rtf)
        source.setString(plain, forType: .string)
        _ = PasteboardHelper.readContent(from: source)

        source.clearContents()
        source.setString(plain, forType: .string)
        let content = try XCTUnwrap(PasteboardHelper.readContent(from: source))

        PasteboardHelper.write(content: content, to: target)
        XCTAssertNil(target.data(forType: .rtf))
    }
}
