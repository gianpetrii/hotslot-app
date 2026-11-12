import XCTest
@testable import HotSlot

@MainActor
final class MoreSlotsTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HotSlotMoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        AppSupportDirectory.rootOverride = tempDir
    }

    override func tearDown() async throws {
        AppSupportDirectory.rootOverride = nil
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func makeStore() -> (LibraryWorkspaceStore, SlotStore) {
        let workspace = LibraryWorkspaceStore()
        return (workspace, SlotStore(workspace: workspace))
    }

    func testNewLibraryHasFiveEmptySlots() {
        let (_, store) = makeStore()
        XCTAssertEqual(store.totalSlotCount, 5)
        XCTAssertTrue(store.allSlots.allSatisfy { $0.content == nil })
    }

    func testAddSlotGoesToTheEndAndOnlyFirstFiveHaveShortcut() {
        let (_, store) = makeStore()
        let order = store.addSlot(content: .text("sexto"))
        XCTAssertEqual(order, 6)
        XCTAssertEqual(store.totalSlotCount, 6)
        XCTAssertEqual(store.slots.count, SlotStore.slotCount)
        XCTAssertEqual(store.content(at: 6)?.previewText, "sexto")
    }

    func testAddEmptySlotIsEmptyKind() {
        let (workspace, store) = makeStore()
        store.addSlot()
        let record = workspace.activeSlot(order: 6)
        XCTAssertEqual(record?.kind, .empty)
        XCTAssertNil(record?.clipContent())
    }

    func testClearingASlotLeavesItEmptyKind() {
        let (workspace, store) = makeStore()
        store.saveContent(index: 2, content: .text("algo"))
        store.clearSlot(index: 2)
        XCTAssertEqual(workspace.activeSlot(order: 2)?.kind, .empty)
    }

    func testMoveSlotShiftsTheOthersInsteadOfSwapping() {
        let (_, store) = makeStore()
        store.saveContent(index: 1, content: .text("uno"))
        store.saveContent(index: 2, content: .text("dos"))
        store.saveContent(index: 3, content: .text("tres"))
        store.addSlot(content: .text("seis"))

        XCTAssertTrue(store.moveSlot(from: 6, to: 1))

        XCTAssertEqual(store.content(at: 1)?.previewText, "seis")
        XCTAssertEqual(store.content(at: 2)?.previewText, "uno")
        XCTAssertEqual(store.content(at: 3)?.previewText, "dos")
        XCTAssertEqual(store.content(at: 4)?.previewText, "tres")
        XCTAssertEqual(store.totalSlotCount, 6)
    }

    func testSwapSlotsExchangesOnlyThosePositions() {
        let (_, store) = makeStore()
        store.saveContent(index: 1, content: .text("uno"))
        store.saveContent(index: 2, content: .text("dos"))
        store.addSlot(content: .text("seis"))
        store.updateLabel(index: 6, label: "Mi seis")

        XCTAssertTrue(store.swapSlots(1, 6))

        XCTAssertEqual(store.content(at: 1)?.previewText, "seis")
        XCTAssertEqual(store.slot(at: 1)?.label, "Mi seis")
        XCTAssertEqual(store.content(at: 2)?.previewText, "dos")
        XCTAssertEqual(store.content(at: 6)?.previewText, "uno")
        XCTAssertEqual(store.totalSlotCount, 6)
    }

    func testMoveToTheSamePositionOrOutOfRangeDoesNothing() {
        let (_, store) = makeStore()
        XCTAssertFalse(store.moveSlot(from: 2, to: 2))
        XCTAssertFalse(store.moveSlot(from: 2, to: 9))
        XCTAssertFalse(store.moveSlot(from: 9, to: 1))
    }

    func testRemoveSlotRenumbersTheRest() {
        let (_, store) = makeStore()
        store.addSlot(content: .text("seis"))
        store.addSlot(content: .text("siete"))

        XCTAssertTrue(store.removeSlot(index: 6))

        XCTAssertEqual(store.totalSlotCount, 6)
        XCTAssertEqual(store.content(at: 6)?.previewText, "siete")
        XCTAssertNil(store.slot(at: 7))
    }

    func testSlotsBeyondFivePersist() {
        let (_, store) = makeStore()
        store.addSlot(content: .text("sexto"))

        let reopened = SlotStore(workspace: LibraryWorkspaceStore())
        XCTAssertEqual(reopened.totalSlotCount, 6)
        XCTAssertEqual(reopened.content(at: 6)?.previewText, "sexto")
    }

    func testEachLibraryCountsItsOwnSlots() {
        let (workspace, store) = makeStore()
        store.addSlot(content: .text("extra"))
        workspace.createLibrary(named: "Otra")
        XCTAssertEqual(store.totalSlotCount, 5)
    }
}
