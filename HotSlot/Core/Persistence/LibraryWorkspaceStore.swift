import Foundation

/// Persistencia del workspace (bibliotecas + slots) para el rediseño.
@MainActor
@Observable
final class LibraryWorkspaceStore {
    private(set) var workspace: SlotsWorkspace

    init() {
        let loaded = Self.loadFromDisk() ?? SlotsWorkspace.empty()
        let normalized = Self.normalizingBackgrounds(loaded)
        workspace = normalized
        if normalized != loaded {
            save()
        }
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

    /// Sincroniza los 5 slots legacy (`SlotStore`) con la biblioteca activa.
    /// `preservingMissingBackgrounds` solo en el arranque: el archivo viejo de slots
    /// puede tener colores que el workspace todavía no guardaba.
    func applyActiveLibrary(to slotStore: SlotStore, preservingMissingBackgrounds: Bool = false) {
        let records = activeSlots()
        let previous = slotStore.slots
        var legacy = Slot.defaultSlots()
        for record in records {
            guard let index = legacy.firstIndex(where: { $0.index == record.order }) else { continue }
            legacy[index].label = record.title
            legacy[index].content = record.clipContent()
            if let hex = record.cardBackgroundHex {
                legacy[index].cardBackgroundHex = hex
            } else if preservingMissingBackgrounds {
                legacy[index].cardBackgroundHex = previous.first { $0.index == record.order }?.cardBackgroundHex
            }
        }
        slotStore.replaceAll(legacy)
    }

    /// Importa el `slots.json` legacy a la biblioteca activa si el workspace está vacío.
    func importLegacySlotsIfNeeded(from slotStore: SlotStore) {
        let hasContent = workspace.slots.contains { $0.clipContent() != nil }
        guard !hasContent else { return }

        let now = Date()
        var records = activeSlots()
        for slot in slotStore.slots {
            guard let i = records.firstIndex(where: { $0.order == slot.index }) else { continue }
            records[i].title = slot.label
            records[i].cardBackgroundHex = slot.cardBackgroundHex
            if let content = slot.content {
                switch content {
                case .text(let string):
                    records[i].kind = string.hasPrefix("http") ? .link : .text
                    records[i].textPayload = string
                    records[i].meta = wordCountMeta(string)
                case .image(let fileName):
                    records[i].kind = .image
                    records[i].imageFileName = fileName
                    records[i].meta = "Imagen"
                case .file(let path, let bookmark):
                    records[i].kind = .file
                    records[i].filePath = path
                    records[i].fileBookmark = bookmark
                    records[i].meta = content.typeLabel
                }
            }
            records[i].updatedAt = now
        }
        for record in records {
            if let idx = workspace.slots.firstIndex(where: { $0.id == record.id }) {
                workspace.slots[idx] = record
            }
        }
        save()
    }

    /// Mueve el contenido del slot `order` de la biblioteca activa al primer slot vacío de `toLibraryId`.
    @discardableResult
    func moveSlotContent(order: Int, toLibraryId: UUID) -> Bool {
        let fromId = workspace.activeLibraryId
        guard fromId != toLibraryId else { return false }
        guard let fromIdx = workspace.slots.firstIndex(where: { $0.libraryId == fromId && $0.order == order }),
              workspace.slots[fromIdx].clipContent() != nil else { return false }
        guard let toIdx = workspace.slots.firstIndex(where: { $0.libraryId == toLibraryId && $0.clipContent() == nil }) else {
            return false
        }

        let now = Date()
        var source = workspace.slots[fromIdx]
        var dest = workspace.slots[toIdx]
        dest.title = source.title
        dest.kind = source.kind
        dest.textPayload = source.textPayload
        dest.imageFileName = source.imageFileName
        dest.filePath = source.filePath
        dest.fileBookmark = source.fileBookmark
        dest.linkURL = source.linkURL
        dest.meta = source.meta
        dest.cardBackgroundHex = source.cardBackgroundHex
        dest.updatedAt = now

        source.textPayload = nil
        source.imageFileName = nil
        source.filePath = nil
        source.fileBookmark = nil
        source.linkURL = nil
        source.kind = .text
        source.meta = nil
        source.updatedAt = now

        workspace.slots[fromIdx] = source
        workspace.slots[toIdx] = dest
        save()
        return true
    }

    func syncFromLegacySlotStore(_ slotStore: SlotStore) {
        let libraryId = workspace.activeLibraryId
        let now = Date()
        for slot in slotStore.slots {
            guard let idx = workspace.slots.firstIndex(where: { $0.libraryId == libraryId && $0.order == slot.index }) else {
                continue
            }
            workspace.slots[idx].title = slot.label
            workspace.slots[idx].cardBackgroundHex = slot.cardBackgroundHex
            workspace.slots[idx].updatedAt = now
            if let content = slot.content {
                switch content {
                case .text(let string):
                    workspace.slots[idx].kind = string.hasPrefix("http") ? .link : .text
                    workspace.slots[idx].textPayload = string
                    workspace.slots[idx].imageFileName = nil
                    workspace.slots[idx].filePath = nil
                    workspace.slots[idx].fileBookmark = nil
                    workspace.slots[idx].meta = wordCountMeta(string)
                case .image(let fileName):
                    workspace.slots[idx].kind = .image
                    workspace.slots[idx].imageFileName = fileName
                    workspace.slots[idx].filePath = nil
                    workspace.slots[idx].fileBookmark = nil
                    workspace.slots[idx].textPayload = nil
                    workspace.slots[idx].meta = "Imagen"
                case .file(let path, let bookmark):
                    workspace.slots[idx].kind = .file
                    workspace.slots[idx].filePath = path
                    workspace.slots[idx].fileBookmark = bookmark
                    workspace.slots[idx].textPayload = nil
                    workspace.slots[idx].imageFileName = nil
                    workspace.slots[idx].meta = content.typeLabel
                }
            } else {
                workspace.slots[idx].textPayload = nil
                workspace.slots[idx].imageFileName = nil
                workspace.slots[idx].filePath = nil
                workspace.slots[idx].fileBookmark = nil
                workspace.slots[idx].kind = .text
                workspace.slots[idx].meta = nil
            }
        }
        save()
    }

    private func save() {
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

    private func wordCountMeta(_ text: String) -> String {
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        return "\(words) palabras"
    }
}
