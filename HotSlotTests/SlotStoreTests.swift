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

    func testSwapContentsKeepsSlotNumbers() {
        let store = SlotStore()
        store.saveContent(index: 1, content: .text("uno"))
        store.saveContent(index: 3, content: .text("tres"))
        store.swapContents(from: 1, to: 3)

        XCTAssertEqual(store.content(at: 1)?.previewText, "tres")
        XCTAssertEqual(store.content(at: 3)?.previewText, "uno")
        XCTAssertEqual(store.slot(at: 1)?.index, 1)
        XCTAssertEqual(store.slot(at: 3)?.index, 3)
    }

    func testSwapWithEmptySlot() {
        let store = SlotStore()
        store.saveContent(index: 2, content: .text("lleno"))
        store.swapContents(from: 2, to: 5)

        XCTAssertNil(store.content(at: 2))
        XCTAssertEqual(store.content(at: 5)?.previewText, "lleno")
    }

    func testSlotsLiveOnlyInTheWorkspaceDatabase() {
        let store = SlotStore()
        store.saveContent(index: 1, content: .text("uno"))

        XCTAssertFalse(FileManager.default.fileExists(atPath: AppSupportDirectory.slotsFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: AppSupportDirectory.workspaceFile.path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: AppSupportDirectory.root.appendingPathComponent("Workspace.store").path
        ))
    }

    func testClearingKeepsLabelAndBackground() {
        let workspace = LibraryWorkspaceStore()
        let store = SlotStore(workspace: workspace)
        store.updateLabel(index: 4, label: "Mi título")
        store.saveContent(index: 4, content: .text("algo"))
        store.clearSlot(index: 4)

        XCTAssertNil(store.content(at: 4))
        XCTAssertEqual(store.slot(at: 4)?.label, "Mi título")
    }

    func testEachLibraryKeepsItsOwnSlots() {
        let workspace = LibraryWorkspaceStore()
        let store = SlotStore(workspace: workspace)
        let first = workspace.workspace.activeLibraryId
        store.saveContent(index: 1, content: .text("de la primera"))

        workspace.createLibrary(named: "Otra")
        XCTAssertNil(store.content(at: 1))
        store.saveContent(index: 1, content: .text("de la segunda"))

        workspace.setActiveLibrary(id: first)
        XCTAssertEqual(store.content(at: 1)?.previewText, "de la primera")
    }

    func testLegacyMigrationFillsGapsAndNeverOverwrites() throws {
        let workspace = LibraryWorkspaceStore()
        let store = SlotStore(workspace: workspace)
        store.saveContent(index: 1, content: .text("del workspace"))

        let legacy = [
            Slot(index: 1, label: "Slot 1", content: .text("viejo"), cardBackgroundHex: nil),
            Slot(index: 2, label: "Mi título", content: .text("solo en legacy"), cardBackgroundHex: nil),
        ]
        try JSONEncoder().encode(legacy).write(to: AppSupportDirectory.slotsFile)

        workspace.migrateLegacySlotsIfNeeded()

        XCTAssertEqual(store.content(at: 1)?.previewText, "del workspace")
        XCTAssertEqual(store.content(at: 2)?.previewText, "solo en legacy")
        XCTAssertEqual(store.slot(at: 2)?.label, "Mi título")
        XCTAssertFalse(FileManager.default.fileExists(atPath: AppSupportDirectory.slotsFile.path))

        let moved = AppSupportDirectory.root.appendingPathComponent("slots.json.migrado")
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.path))
        let backups = AppSupportDirectory.root.appendingPathComponent("Backups")
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: backups.path).isEmpty)
    }
}
