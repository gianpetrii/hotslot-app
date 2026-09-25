import Foundation

/// Almacén de los 5 slots fijos.
@MainActor
@Observable
final class SlotStore {
    static let slotCount = 5

    private(set) var slots: [Slot] = Slot.defaultSlots()

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
        slots = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(slots) else { return }
        try? data.write(to: AppSupportDirectory.slotsFile, options: .atomic)
    }

    // MARK: - Testing helpers

    func replaceAll(_ newSlots: [Slot]) {
        slots = newSlots
        save()
    }
}
