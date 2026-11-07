import Foundation

/// Almacén de los 5 slots fijos.
@MainActor
@Observable
final class SlotStore {
    static let slotCount = 5

    private(set) var slots: [Slot] = Slot.defaultSlots()

    /// Llamado tras cada persistencia en disco (sync workspace, analytics, etc.).
    var onPersist: (() -> Void)?

    init() {
        load()
    }

    func slot(at index: Int) -> Slot? {
        slots.first { $0.index == index }
    }

    func updateLabel(index: Int, label: String) {
        guard let i = slots.firstIndex(where: { $0.index == index }) else { return }
        slots[i].label = label
        save()
    }

    func updateCardBackground(index: Int, hex: String?) {
        guard let i = slots.firstIndex(where: { $0.index == index }) else { return }
        slots[i].cardBackgroundHex = SlotsPalette.storedBackgroundHex(hex)
        save()
    }

    func saveContent(index: Int, content: ClipContent) {
        guard let i = slots.firstIndex(where: { $0.index == index }) else { return }
        slots[i].content = content
        save()
    }

    func clearSlot(index: Int) {
        guard let i = slots.firstIndex(where: { $0.index == index }) else { return }
        slots[i].content = nil
        save()
    }

    /// Intercambia el contenido entre dos slots. El número (y su atajo) no se mueve.
    func swapContents(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              let i = slots.firstIndex(where: { $0.index == sourceIndex }),
              let j = slots.firstIndex(where: { $0.index == destinationIndex }) else { return }
        let sourceContent = slots[i].content
        slots[i].content = slots[j].content
        slots[j].content = sourceContent
        save()
    }

    func content(at index: Int) -> ClipContent? {
        slot(at: index)?.content
    }

    private func load() {
        guard let data = try? Data(contentsOf: AppSupportDirectory.slotsFile),
              let decoded = try? JSONDecoder().decode([Slot].self, from: data) else {
            slots = Slot.defaultSlots()
            return
        }
        let normalized = decoded.map { slot in
            var slot = slot
            slot.cardBackgroundHex = SlotsPalette.storedBackgroundHex(slot.cardBackgroundHex)
            return slot
        }
        slots = normalized
        if normalized != decoded {
            save()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(slots) else { return }
        try? data.write(to: AppSupportDirectory.slotsFile, options: .atomic)
        onPersist?()
    }

    // MARK: - Testing helpers

    func replaceAll(_ newSlots: [Slot]) {
        slots = newSlots
        save()
    }
}
