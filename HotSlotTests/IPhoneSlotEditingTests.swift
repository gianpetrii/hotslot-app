import XCTest
@testable import HotSlot

/// Lo que usa la app de iPhone para editar y deshacer, probado desde el target del Mac (el código es compartido).
@MainActor
final class IPhoneSlotEditingTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HotSlotIPhoneTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        AppSupportDirectory.rootOverride = tempDir
    }

    override func tearDown() async throws {
        AppSupportDirectory.rootOverride = nil
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testUpdateSlotByIdChangesOnlyThatSlot() throws {
        let store = LibraryWorkspaceStore()
        let libraryId = store.workspace.activeLibraryId
        let first = try XCTUnwrap(store.slots(for: libraryId).first)
        store.updateSlot(id: first.id) { $0.title = "Mi portfolio" }
        XCTAssertEqual(store.slot(id: first.id)?.title, "Mi portfolio")
        XCTAssertEqual(store.slots(for: libraryId).dropFirst().first?.title, "Slot 2")
    }

    func testRestoreBringsBackARemovedSlotAtItsPosition() throws {
        let store = LibraryWorkspaceStore()
        let libraryId = store.workspace.activeLibraryId
        store.addSlot(toLibraryId: libraryId, content: .text("sexto"), title: "Sexto")
        store.addSlot(toLibraryId: libraryId, content: .text("séptimo"), title: "Séptimo")
        let sixth = try XCTUnwrap(store.slots(for: libraryId).first { $0.order == 6 })

        store.removeSlot(libraryId: libraryId, order: 6)
        XCTAssertEqual(store.slotCount(in: libraryId), 6)
        XCTAssertEqual(store.slots(for: libraryId).last?.title, "Séptimo")

        store.restoreSlot(sixth)
        let slots = store.slots(for: libraryId)
        XCTAssertEqual(slots.map(\.order), [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(slots[5].title, "Sexto")
        XCTAssertEqual(slots[6].title, "Séptimo")
    }

    func testRestoreAfterClearingBringsBackContent() throws {
        let store = LibraryWorkspaceStore()
        let libraryId = store.workspace.activeLibraryId
        store.addSlot(toLibraryId: libraryId, content: .text("hola"), title: "Saludo")
        let slot = try XCTUnwrap(store.slots(for: libraryId).first { $0.title == "Saludo" })

        store.updateSlot(id: slot.id) { $0.setContent(nil) }
        XCTAssertNil(store.slot(id: slot.id)?.clipContent())
        XCTAssertEqual(store.slot(id: slot.id)?.title, "Saludo")

        store.restoreSlot(slot)
        XCTAssertEqual(store.slot(id: slot.id)?.clipContent(), .text("hola"))
    }

    func testSwapKeepsContentWithTheirSlots() throws {
        let store = LibraryWorkspaceStore()
        let libraryId = store.workspace.activeLibraryId
        store.addSlot(toLibraryId: libraryId, content: .text("a"), title: "A")
        store.addSlot(toLibraryId: libraryId, content: .text("b"), title: "B")
        let a = try XCTUnwrap(store.slots(for: libraryId).first { $0.title == "A" })
        let b = try XCTUnwrap(store.slots(for: libraryId).first { $0.title == "B" })

        store.swapSlots(libraryId: libraryId, a.order, b.order)
        XCTAssertEqual(store.slot(id: a.id)?.order, b.order)
        XCTAssertEqual(store.slot(id: b.id)?.order, a.order)
        XCTAssertEqual(store.slot(id: a.id)?.clipContent(), .text("a"))
    }
}
