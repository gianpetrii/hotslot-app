import Foundation

/// Persistencia del workspace (bibliotecas + slots) para el rediseño.
@MainActor
@Observable
final class LibraryWorkspaceStore {
    private(set) var workspace: SlotsWorkspace
    /// SwiftData + iCloud. `nil` si no abrió: entonces todo sigue en el JSON de siempre.
    @ObservationIgnored private let database: WorkspaceDatabase?
    /// Base vacía y sin JSON viejo: las bibliotecas de arranque están solo en memoria hasta que
    /// termine el primer import de iCloud. Así un dispositivo nuevo no resucita bibliotecas ya borradas.
    @ObservationIgnored private var seedPending = false

    init() {
        let database = WorkspaceDatabase()
        self.database = database
        let loaded = Self.initialWorkspace(database: database)
        seedPending = loaded.deferredSeed
        let normalized = Self.normalizingBackgrounds(loaded.workspace)
        workspace = normalized
        if normalized != loaded.workspace, !seedPending {
            save()
        }
        database?.onRemoteChange = { [weak self] in self?.reloadFromDatabase() }
        if seedPending, let database {
            Task { @MainActor [weak self] in
                await database.waitForFirstImport(timeout: 15)
                self?.resolveSeed()
            }
        }
    }

    /// Cambios que llegan de otro dispositivo.
    private func reloadFromDatabase() {
        guard let loaded = database?.load() else { return }
        seedPending = false
        let normalized = Self.normalizingBackgrounds(loaded)
        if normalized != workspace { workspace = normalized }
    }

    /// Terminó la espera: si llegaron datos de iCloud se usan; si no, se guardan las bibliotecas de arranque.
    private func resolveSeed() {
        guard seedPending, let database else { return }
        seedPending = false
        if let stored = database.load() {
            let normalized = Self.normalizingBackgrounds(stored)
            if normalized != workspace { workspace = normalized }
        } else {
            database.write(workspace)
        }
    }

    /// Lee la base. Si está vacía, pasa el JSON anterior a la base (con copia de seguridad) o parte de cero.
    private static func initialWorkspace(database: WorkspaceDatabase?) -> (workspace: SlotsWorkspace, deferredSeed: Bool) {
        guard let database else { return (loadFromDisk() ?? SlotsWorkspace.empty(), false) }
        if let stored = database.load() { return (stored, false) }

        let legacy = loadFromDisk()
        if legacy != nil {
            AppSupportDirectory.backupDataFiles(label: "antes-de-swiftdata")
        }
        // Las bibliotecas y slots de arranque llevan fecha 0: si ya hay datos en iCloud, siempre pierden
        // contra ellos al fusionar duplicados. Cualquier edición del usuario les pone fecha real.
        let initial = legacy ?? SlotsWorkspace.empty(now: Date(timeIntervalSince1970: 0))
        if legacy == nil, database.syncsWithCloud {
            return (initial, true)
        }
        database.write(initial)
        if legacy != nil {
            let fm = FileManager.default
            let moved = AppSupportDirectory.workspaceFile
                .deletingLastPathComponent()
                .appendingPathComponent("libraries-workspace.json.migrado")
            try? fm.removeItem(at: moved)
            try? fm.moveItem(at: AppSupportDirectory.workspaceFile, to: moved)
        }
        return (initial, false)
    }

    var activeLibrary: Library? {
        workspace.libraries.first { $0.id == workspace.activeLibraryId }
    }

    func slots(for libraryId: UUID) -> [SlotRecord] {
        workspace.slots
            .filter { $0.libraryId == libraryId }
            .sorted { $0.order < $1.order }
    }

    func activeSlots() -> [SlotRecord] {
        slots(for: workspace.activeLibraryId)
    }

    func setActiveLibrary(id: UUID) {
        guard workspace.libraries.contains(where: { $0.id == id }) else { return }
        workspace.activeLibraryId = id
        save()
    }

    func filledSlotCount(in libraryId: UUID) -> Int {
        workspace.slots.filter { $0.libraryId == libraryId && $0.clipContent() != nil }.count
    }

    /// Nueva biblioteca con 5 slots vacíos y la activa.
    func createLibrary(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let now = Date()
        let id = UUID()
        let order = (workspace.libraries.map(\.order).max() ?? -1) + 1
        workspace.libraries.append(
            Library(id: id, name: trimmed, order: order, createdAt: now, updatedAt: now)
        )
        for slotOrder in 1...SlotStore.slotCount {
            workspace.slots.append(
                SlotRecord(
                    id: UUID(),
                    libraryId: id,
                    order: slotOrder,
                    title: "Slot \(slotOrder)",
                    kind: .text,
                    textPayload: nil,
                    imageFileName: nil,
                    linkURL: nil,
                    meta: nil,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }
        workspace.activeLibraryId = id
        save()
    }

    func replaceWorkspace(_ newValue: SlotsWorkspace) {
        workspace = newValue
        save()
    }

    /// Elimina una biblioteca si queda al menos otra; reasigna activa si hace falta.
    @discardableResult
    func deleteLibrary(id: UUID) -> Bool {
        guard workspace.libraries.count > 1 else { return false }
        guard workspace.libraries.contains(where: { $0.id == id }) else { return false }
        workspace.slots.removeAll { $0.libraryId == id }
        workspace.libraries.removeAll { $0.id == id }
        if workspace.activeLibraryId == id {
            workspace.activeLibraryId = workspace.libraries.sorted { $0.order < $1.order }.first!.id
        }
        normalizeLibraryOrders()
        save()
        return true
    }

    func renameLibrary(id: UUID, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = workspace.libraries.firstIndex(where: { $0.id == id }) else { return }
        workspace.libraries[idx].name = trimmed
        workspace.libraries[idx].updatedAt = Date()
        save()
    }

    /// `index` cuenta posiciones en la lista sin la biblioteca movida.
    func moveLibrary(id: UUID, toIndex index: Int) {
        var sorted = workspace.libraries.sorted { $0.order < $1.order }
        guard let fromIdx = sorted.firstIndex(where: { $0.id == id }) else { return }
        let item = sorted.remove(at: fromIdx)
        sorted.insert(item, at: min(max(index, 0), sorted.count))
        applyLibraryOrder(sorted.map(\.id))
    }

    private func applyLibraryOrder(_ orderedIds: [UUID]) {
        for (offset, id) in orderedIds.enumerated() {
            if let idx = workspace.libraries.firstIndex(where: { $0.id == id }) {
                workspace.libraries[idx].order = offset
            }
        }
        save()
    }

    private func normalizeLibraryOrders() {
        let sorted = workspace.libraries.sorted { $0.order < $1.order }
        for (offset, library) in sorted.enumerated() {
            if let idx = workspace.libraries.firstIndex(where: { $0.id == library.id }) {
                workspace.libraries[idx].order = offset
            }
        }
    }

    // MARK: - Edición de la biblioteca activa

    func activeSlot(order: Int) -> SlotRecord? {
        workspace.slots.first { $0.libraryId == workspace.activeLibraryId && $0.order == order }
    }

    /// Edita un slot de la biblioteca activa y guarda.
    func updateActiveSlot(order: Int, _ change: (inout SlotRecord) -> Void) {
        guard let idx = workspace.slots.firstIndex(where: {
            $0.libraryId == workspace.activeLibraryId && $0.order == order
        }) else { return }
        change(&workspace.slots[idx])
        workspace.slots[idx].updatedAt = Date()
        save()
    }

    // MARK: - Migración desde `slots.json`

    /// Hasta la 0.24 los slots de la biblioteca activa también vivían en `slots.json`, copiados de ida y vuelta.
    /// Desde ahora el workspace es la única fuente. Una sola vez: se hace copia de seguridad de los archivos,
    /// se completa lo que el workspace no tuviera (fondos, contenido, nombres) y `slots.json` queda apartado.
    func migrateLegacySlotsIfNeeded() {
        let fm = FileManager.default
        let legacyURL = AppSupportDirectory.slotsFile
        guard fm.fileExists(atPath: legacyURL.path) else { return }

        AppSupportDirectory.backupDataFiles(label: "antes-de-unificar-slots")

        if let data = try? Data(contentsOf: legacyURL),
           let legacy = try? JSONDecoder().decode([Slot].self, from: data) {
            var changed = false
            for slot in legacy {
                updateActiveSlotIfNeeded(order: slot.index, legacy: slot, changed: &changed)
            }
            if changed { save() }
        }

        let moved = legacyURL.deletingLastPathComponent().appendingPathComponent("slots.json.migrado")
        try? fm.removeItem(at: moved)
        try? fm.moveItem(at: legacyURL, to: moved)
    }

    /// Completa solo lo que falta: nunca pisa lo que el workspace ya tiene.
    private func updateActiveSlotIfNeeded(order: Int, legacy: Slot, changed: inout Bool) {
        guard let idx = workspace.slots.firstIndex(where: {
            $0.libraryId == workspace.activeLibraryId && $0.order == order
        }) else { return }
        let record = workspace.slots[idx]

        if record.cardBackgroundHex == nil, let hex = SlotsPalette.storedBackgroundHex(legacy.cardBackgroundHex) {
            workspace.slots[idx].cardBackgroundHex = hex
            changed = true
        }
        let isDefaultTitle = record.title.isEmpty || record.title == "Slot \(order)"
        if isDefaultTitle, !legacy.label.isEmpty, legacy.label != "Slot \(order)" {
            workspace.slots[idx].title = legacy.label
            changed = true
        }
        if record.clipContent() == nil, let content = legacy.content {
            workspace.slots[idx].setContent(content)
            changed = true
        }
    }

    /// Mueve el contenido del slot `order` de la biblioteca activa al primer slot vacío de `toLibraryId`.
    @discardableResult
    /// Orden del primer slot vacío de una biblioteca.
    func firstEmptyOrder(in libraryId: UUID) -> Int? {
        workspace.slots
            .filter { $0.libraryId == libraryId && $0.clipContent() == nil }
            .map(\.order)
            .min()
    }

    /// Guarda un contenido en un slot de cualquier biblioteca (no solo la activa).
    func saveContent(_ content: ClipContent, order: Int, toLibraryId libraryId: UUID) {
        guard let idx = workspace.slots.firstIndex(where: { $0.libraryId == libraryId && $0.order == order }) else { return }
        workspace.slots[idx].setContent(content)
        save()
    }

    /// Pasa un slot con contenido a otra biblioteca, con su contenido, nombre y fondo.
    /// Sin `toOrder` va al primer slot vacío. Con `toOrder` intercambia con ese slot, así no se pierde lo que había.
    @discardableResult
    func transferSlot(fromLibraryId: UUID, order: Int, toLibraryId: UUID, toOrder: Int? = nil) -> Bool {
        guard fromLibraryId != toLibraryId,
              let fromIdx = workspace.slots.firstIndex(where: { $0.libraryId == fromLibraryId && $0.order == order }),
              workspace.slots[fromIdx].clipContent() != nil else { return false }
        let destOrder = toOrder ?? firstEmptyOrder(in: toLibraryId)
        guard let destOrder,
              let toIdx = workspace.slots.firstIndex(where: { $0.libraryId == toLibraryId && $0.order == destOrder }) else {
            return false
        }

        let now = Date()
        var source = workspace.slots[fromIdx]
        var dest = workspace.slots[toIdx]
        Self.swapPayload(&source, &dest)
        source.updatedAt = now
        dest.updatedAt = now
        workspace.slots[fromIdx] = source
        workspace.slots[toIdx] = dest
        save()
        return true
    }

    private static func swapPayload(_ a: inout SlotRecord, _ b: inout SlotRecord) {
        swap(&a.title, &b.title)
        swap(&a.kind, &b.kind)
        swap(&a.textPayload, &b.textPayload)
        swap(&a.imageFileName, &b.imageFileName)
        swap(&a.filePath, &b.filePath)
        swap(&a.fileBookmark, &b.fileBookmark)
        swap(&a.fileName, &b.fileName)
        swap(&a.linkURL, &b.linkURL)
        swap(&a.meta, &b.meta)
        swap(&a.cardBackgroundHex, &b.cardBackgroundHex)
    }

    private func save() {
        if let database {
            seedPending = false
            database.write(workspace)
            return
        }
        guard let data = try? JSONEncoder().encode(workspace) else { return }
        try? data.write(to: AppSupportDirectory.workspaceFile, options: .atomic)
    }

    private static func normalizingBackgrounds(_ workspace: SlotsWorkspace) -> SlotsWorkspace {
        var copy = workspace
        for index in copy.slots.indices {
            copy.slots[index].cardBackgroundHex = SlotsPalette.storedBackgroundHex(copy.slots[index].cardBackgroundHex)
        }
        return copy
    }

    private static func loadFromDisk() -> SlotsWorkspace? {
        guard let data = try? Data(contentsOf: AppSupportDirectory.workspaceFile),
              let decoded = try? JSONDecoder().decode(SlotsWorkspace.self, from: data) else {
            return nil
        }
        return decoded
    }

}
