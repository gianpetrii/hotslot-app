import Foundation

/// Estado de la app de iPhone: las bibliotecas y los slots, sincronizados con iCloud.
@MainActor
@Observable
final class AppModel {
    let store = LibraryWorkspaceStore()

    init() {
        #if DEBUG
        DebugSampleData.loadIfRequested(into: store)
        #endif
    }

    var libraries: [Library] {
        store.workspace.libraries.sorted { $0.order < $1.order }
    }

    var activeLibraryId: UUID { store.workspace.activeLibraryId }

    /// Copia el contenido del slot al portapapeles. `false` si no hay nada para copiar.
    @discardableResult
    func copy(_ slot: SlotRecord) -> Bool {
        SlotClipboard.copy(slot)
    }

    // MARK: - Slots

    /// Guarda un contenido nuevo. Va al slot indicado, o al primer slot vacío de la biblioteca, o a uno nuevo al final.
    @discardableResult
    func saveNewSlot(content: ClipContent, title: String, libraryId: UUID, intoSlotId: UUID? = nil) -> UUID? {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let empty = store.slots(for: libraryId).first { $0.clipContent() == nil }
        let target = intoSlotId.flatMap { store.slot(id: $0) }.flatMap { $0.libraryId == libraryId ? $0 : nil } ?? empty
        if let target {
            store.updateSlot(id: target.id) { record in
                record.setContent(content)
                if !name.isEmpty { record.title = name }
            }
            return target.id
        }
        guard let order = store.addSlot(toLibraryId: libraryId, content: content, title: name.isEmpty ? nil : name) else {
            return nil
        }
        return store.slots(for: libraryId).first { $0.order == order }?.id
    }

    /// Aplica los cambios de «Editar slot».
    func applyEdit(slotId: UUID, title: String, content: ClipContent?, contentChanged: Bool, libraryId: UUID) {
        guard let original = store.slot(id: slotId) else { return }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        store.updateSlot(id: slotId) { record in
            if !name.isEmpty { record.title = name }
            if contentChanged { record.setContent(content) }
        }
        if libraryId != original.libraryId { move(slotId: slotId, toLibraryId: libraryId) }
    }

    /// Reemplaza el contenido por lo que hay en el portapapeles (acá sí se lee).
    @discardableResult
    func replaceFromClipboard(slotId: UUID) -> Bool {
        guard let content = ClipboardReader.read() else { return false }
        store.updateSlot(id: slotId) { $0.setContent(content) }
        return true
    }

    /// Pasa el slot a otra biblioteca: al primer slot vacío o, si no hay, a uno nuevo.
    func move(slotId: UUID, toLibraryId: UUID) {
        guard let slot = store.slot(id: slotId), slot.libraryId != toLibraryId else { return }
        if store.firstEmptyOrder(in: toLibraryId) == nil {
            store.addSlot(toLibraryId: toLibraryId)
        }
        store.transferSlot(fromLibraryId: slot.libraryId, order: slot.order, toLibraryId: toLibraryId)
    }

    func setBackground(slotId: UUID, hex: String?) {
        store.updateSlot(id: slotId) { $0.cardBackgroundHex = hex }
    }

    /// Los primeros slots (los que tienen atajo en el Mac) solo se vacían; el resto se puede quitar una vez vacío.
    func canRemove(_ slot: SlotRecord) -> Bool {
        slot.clipContent() == nil && slot.order > SlotStore.slotCount
    }

    /// Igual que en el Mac: un slot con contenido se vacía; uno ya vacío (del 6 en adelante) se quita.
    /// Devuelve el slot como estaba, para deshacer.
    func delete(slotId: UUID) -> SlotRecord? {
        guard let slot = store.slot(id: slotId) else { return nil }
        if slot.clipContent() != nil {
            store.updateSlot(id: slotId) { $0.setContent(nil) }
            return slot
        }
        guard canRemove(slot) else { return nil }
        store.removeSlot(libraryId: slot.libraryId, order: slot.order)
        return slot
    }

    func undoDelete(_ slot: SlotRecord) {
        store.restoreSlot(slot)
    }

    /// Reordenar intercambia dos slots, como en el Mac.
    func swap(_ a: UUID, _ b: UUID) {
        guard let first = store.slot(id: a), let second = store.slot(id: b),
              first.libraryId == second.libraryId else { return }
        store.swapSlots(libraryId: first.libraryId, first.order, second.order)
    }

    // MARK: - Bibliotecas

    func isLibraryNameTaken(_ name: String, excluding id: UUID? = nil) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.workspace.libraries.contains {
            $0.id != id && $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    /// Crea la biblioteca y la deja activa. Devuelve su id.
    @discardableResult
    func createLibrary(named name: String) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLibraryNameTaken(trimmed) else { return nil }
        store.createLibrary(named: trimmed)
        return store.workspace.activeLibraryId
    }
}
