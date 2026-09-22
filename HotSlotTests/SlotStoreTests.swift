import XCTest
@testable import HotSlot

@MainActor
final class SlotStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HotSlotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        AppSupportDirectory.rootOverride = tempDir
    }

    override func tearDown() async throws {
        AppSupportDirectory.rootOverride = nil
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testDefaultSlotCount() {
        let store = SlotStore()
        XCTAssertEqual(store.slots.count, SlotStore.slotCount)
    }

    func testSaveAndLoadContent() {
        let store = SlotStore()
        store.saveContent(index: 1, content: .text("slot uno"))
        XCTAssertEqual(store.content(at: 1)?.previewText, "slot uno")

        let reloaded = SlotStore()
        XCTAssertEqual(reloaded.content(at: 1)?.previewText, "slot uno")
    }

    func testUpdateLabel() {
        let store = SlotStore()
        store.updateLabel(index: 3, label: "Código")
        XCTAssertEqual(store.slot(at: 3)?.label, "Código")
    }

    func testClearSlot() {
        let store = SlotStore()
        store.saveContent(index: 2, content: .text("temporal"))
        store.clearSlot(index: 2)
        XCTAssertNil(store.content(at: 2))
    }
}
