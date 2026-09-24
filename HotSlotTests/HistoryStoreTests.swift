import XCTest
@testable import HotSlot

@MainActor
final class HistoryStoreTests: XCTestCase {
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

    func testDeduplicationMovesToTop() {
        let store = HistoryStore()
        let a = ClipItem(content: .text("duplicado"))
        let b = ClipItem(content: .text("otro"))
        store.add(a)
        store.add(b)
        XCTAssertEqual(store.items.count, 2)

        let a2 = ClipItem(content: .text("duplicado"))
        store.add(a2)
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items.first?.content.previewText, "duplicado")
    }

    func testHistoryLimit() {
        let store = HistoryStore()
        store.historyLimit = 3
        for i in 0..<5 {
            store.add(ClipItem(content: .text("item \(i)")))
        }
        XCTAssertEqual(store.items.count, 3)
        XCTAssertEqual(store.items.first?.content.previewText, "item 4")
    }

    func testPersistenceRoundTrip() {
        let store1 = HistoryStore()
        store1.add(ClipItem(content: .text("persistido")))
        let store2 = HistoryStore()
        XCTAssertEqual(store2.items.count, 1)
        XCTAssertEqual(store2.items.first?.content.previewText, "persistido")
    }

    func testPinMovesToTop() {
        let store = HistoryStore()
        let pinned = ClipItem(content: .text("fijado"))
        let recent = ClipItem(content: .text("reciente"))
        store.add(recent)
        store.add(pinned)
        store.togglePin(id: pinned.id)

        XCTAssertTrue(store.items.first?.isPinned == true)
        XCTAssertEqual(store.items.first?.content.previewText, "fijado")
    }

    func testNewItemsInsertBelowPinned() {
        let store = HistoryStore()
        let pinned = ClipItem(content: .text("fijado"))
        store.add(pinned)
        store.togglePin(id: pinned.id)

        store.add(ClipItem(content: .text("nuevo")))
        XCTAssertEqual(store.items.count, 2)
        XCTAssertTrue(store.items[0].isPinned)
        XCTAssertEqual(store.items[1].content.previewText, "nuevo")
    }

    func testMoveReordersItems() {
        let store = HistoryStore()
        store.replaceAll([
            ClipItem(content: .text("a")),
            ClipItem(content: .text("b")),
            ClipItem(content: .text("c")),
        ])
        store.move(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(store.items.map(\.content.previewText), ["c", "a", "b"])
    }
}
