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
