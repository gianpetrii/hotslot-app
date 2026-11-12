import XCTest
@testable import HotSlot

@MainActor
final class WorkspaceDatabaseTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HotSlotDBTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        AppSupportDirectory.rootOverride = tempDir
    }

    override func tearDown() async throws {
        AppSupportDirectory.rootOverride = nil
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testRoundTripKeepsLibrariesAndSlots() throws {
        let database = try XCTUnwrap(WorkspaceDatabase())
        var workspace = SlotsWorkspace.empty()
        workspace.slots[0].setContent(.text("hola"))
        workspace.slots[0].title = "Saludo"
        database.write(workspace)

        let loaded = try XCTUnwrap(database.load())
        XCTAssertEqual(loaded.libraries.count, 3)
        XCTAssertEqual(loaded.slots.count, 15)
        let slot = try XCTUnwrap(loaded.slots.first { $0.id == workspace.slots[0].id })
        XCTAssertEqual(slot.title, "Saludo")
        XCTAssertEqual(slot.clipContent()?.previewText, "hola")
    }

    func testWriteDeletesRemovedLibraryAndItsSlots() throws {
        let database = try XCTUnwrap(WorkspaceDatabase())
        var workspace = SlotsWorkspace.empty()
        database.write(workspace)

        let removed = workspace.libraries[2].id
        workspace.libraries.removeAll { $0.id == removed }
        workspace.slots.removeAll { $0.libraryId == removed }
        database.write(workspace)

        let loaded = try XCTUnwrap(database.load())
        XCTAssertEqual(loaded.libraries.count, 2)
        XCTAssertEqual(loaded.slots.count, 10)
    }

    func testFileReferenceStaysLocalAndOnlyTheNameIsSynced() throws {
        let database = try XCTUnwrap(WorkspaceDatabase())
        var workspace = SlotsWorkspace.empty()
        workspace.slots[0].setContent(.file(path: "/Users/yo/Docs/informe.pdf", bookmark: Data([1, 2, 3])))
        database.write(workspace)

        let loaded = try XCTUnwrap(database.load())
        let slot = try XCTUnwrap(loaded.slots.first { $0.id == workspace.slots[0].id })
        XCTAssertEqual(slot.filePath, "/Users/yo/Docs/informe.pdf")
        XCTAssertEqual(slot.fileBookmark, Data([1, 2, 3]))
    }

    func testFileSlotOnAnotherDeviceShowsNameAsRemoteOnly() throws {
        let database = try XCTUnwrap(WorkspaceDatabase())
        var workspace = SlotsWorkspace.empty()
        workspace.slots[0].setContent(.file(path: "/Users/yo/Docs/informe.pdf", bookmark: nil))
        database.write(workspace)

        // Otro dispositivo: llegan los datos pero no la ruta local.
        LocalFileReferences.save([:])
        let loaded = try XCTUnwrap(database.load())
        let slot = try XCTUnwrap(loaded.slots.first { $0.id == workspace.slots[0].id })
        let content = try XCTUnwrap(slot.clipContent())
        XCTAssertTrue(content.isRemoteOnlyFile)
        XCTAssertEqual(content.fileName, "informe.pdf")
        XCTAssertEqual(content.fileDetail, "Solo en otro dispositivo")
        XCTAssertNil(slot.filePath)
    }

    func testSavingRemoteOnlyFileKeepsOnlyTheName() {
        var record = SlotsWorkspace.empty().slots[0]
        record.setContent(.file(path: ClipContent.remoteOnlyPathPrefix + "informe.pdf", bookmark: nil))
        XCTAssertNil(record.filePath)
        XCTAssertEqual(record.fileName, "informe.pdf")
        XCTAssertTrue(record.clipContent()?.isRemoteOnlyFile == true)
    }

    private func slotRecord(library: UUID, order: Int, text: String, at seconds: TimeInterval) -> SlotRecord {
        let date = Date(timeIntervalSince1970: seconds)
        var record = SlotRecord(
            id: UUID(), libraryId: library, order: order, title: "Slot \(order)", kind: .empty,
            textPayload: nil, imageFileName: nil, linkURL: nil, meta: nil, createdAt: date, updatedAt: date
        )
        record.setContent(.text(text), now: date)
        return record
    }

    func testTwoDevicesAddingTheSamePositionKeepBothContents() throws {
        let database = try XCTUnwrap(WorkspaceDatabase())
        var workspace = SlotsWorkspace.empty()
        let library = workspace.libraries[0].id
        workspace.slots.append(slotRecord(library: library, order: 6, text: "de A", at: 1_000))
        workspace.slots.append(slotRecord(library: library, order: 6, text: "de B", at: 2_000))
        database.write(workspace)

        let loaded = try XCTUnwrap(database.load())
        let mine = loaded.slots.filter { $0.libraryId == library }
        XCTAssertEqual(mine.count, 7)
        XCTAssertEqual(mine.first { $0.order == 6 }?.clipContent()?.previewText, "de A")
        XCTAssertEqual(mine.first { $0.order == 7 }?.clipContent()?.previewText, "de B")
    }

    func testUntouchedSeedSlotsLoseAgainstRealOnesAtTheSamePosition() throws {
        let database = try XCTUnwrap(WorkspaceDatabase())
        var workspace = SlotsWorkspace.empty(now: Date(timeIntervalSince1970: 0))
        let library = workspace.libraries[0].id
        workspace.slots.append(slotRecord(library: library, order: 1, text: "real uno", at: 5_000))
        workspace.slots.append(slotRecord(library: library, order: 2, text: "real dos", at: 5_000))
        database.write(workspace)

        let loaded = try XCTUnwrap(database.load())
        let mine = loaded.slots.filter { $0.libraryId == library }
        XCTAssertEqual(mine.count, 5)
        XCTAssertEqual(mine.first { $0.order == 1 }?.clipContent()?.previewText, "real uno")
        XCTAssertEqual(mine.first { $0.order == 2 }?.clipContent()?.previewText, "real dos")
    }

    func testImageBytesTravelAndComeBackAsAFile() throws {
        let database = try XCTUnwrap(WorkspaceDatabase())
        var workspace = SlotsWorkspace.empty()
        let name = "prueba-\(UUID().uuidString).png"
        let url = AppSupportDirectory.images.appendingPathComponent(name)
        try Data([9, 9, 9]).write(to: url)
        workspace.slots[0].setContent(.image(fileName: name))
        database.write(workspace)

        try FileManager.default.removeItem(at: url)
        _ = database.load()
        XCTAssertEqual(try Data(contentsOf: url), Data([9, 9, 9]))
    }

    func testStoreMigratesJSONOnceWithBackup() throws {
        var legacy = SlotsWorkspace.empty()
        legacy.slots[0].setContent(.text("del JSON"))
        try JSONEncoder().encode(legacy).write(to: AppSupportDirectory.workspaceFile)

        let store = LibraryWorkspaceStore()
        XCTAssertEqual(store.workspace.slots.first { $0.id == legacy.slots[0].id }?.clipContent()?.previewText, "del JSON")
        XCTAssertFalse(FileManager.default.fileExists(atPath: AppSupportDirectory.workspaceFile.path))
        let moved = AppSupportDirectory.root.appendingPathComponent("libraries-workspace.json.migrado")
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.path))
        let backups = AppSupportDirectory.root.appendingPathComponent("Backups")
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: backups.path).isEmpty)

        let reopened = LibraryWorkspaceStore()
        XCTAssertEqual(reopened.workspace.slots.first { $0.id == legacy.slots[0].id }?.clipContent()?.previewText, "del JSON")
    }
}
