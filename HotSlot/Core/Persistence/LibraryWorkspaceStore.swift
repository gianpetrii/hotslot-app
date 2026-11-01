import Foundation

/// Persistencia del workspace (bibliotecas + slots) para el rediseño.
@MainActor
@Observable
final class LibraryWorkspaceStore {
    private(set) var workspace: SlotsWorkspace

    init() {
        workspace = Self.loadFromDisk() ?? SlotsWorkspace.empty()
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

    /// Sincroniza los 5 slots legacy (`SlotStore`) con la biblioteca activa.
    func applyActiveLibrary(to slotStore: SlotStore) {
        let records = activeSlots()
        var legacy = Slot.defaultSlots()
        for record in records {
            guard let index = legacy.firstIndex(where: { $0.index == record.order }) else { continue }
            legacy[index].label = record.title
            legacy[index].content = record.clipContent()
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

    func syncFromLegacySlotStore(_ slotStore: SlotStore) {
        let libraryId = workspace.activeLibraryId
        let now = Date()
        for slot in slotStore.slots {
            guard let idx = workspace.slots.firstIndex(where: { $0.libraryId == libraryId && $0.order == slot.index }) else {
                continue
            }
            workspace.slots[idx].title = slot.label
            workspace.slots[idx].updatedAt = now
            if let content = slot.content {
                switch content {
                case .text(let string):
                    workspace.slots[idx].kind = string.hasPrefix("http") ? .link : .text
                    workspace.slots[idx].textPayload = string
                    workspace.slots[idx].imageFileName = nil
                    workspace.slots[idx].meta = wordCountMeta(string)
                case .image(let fileName):
                    workspace.slots[idx].kind = .image
                    workspace.slots[idx].imageFileName = fileName
                    workspace.slots[idx].textPayload = nil
                    workspace.slots[idx].meta = "Imagen"
                }
            } else {
                workspace.slots[idx].textPayload = nil
                workspace.slots[idx].imageFileName = nil
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
