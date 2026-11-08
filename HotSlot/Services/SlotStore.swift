import Foundation

/// Los 5 slots fijos de la biblioteca activa.
/// No guarda nada propio: lee y escribe directamente en el workspace, que es la única fuente de verdad.
@MainActor
@Observable
final class SlotStore {
    static let slotCount = 5

    private let workspace: LibraryWorkspaceStore

    init(workspace: LibraryWorkspaceStore) {
        self.workspace = workspace
    }

    /// Para pruebas: un workspace propio que carga desde el disco.
    convenience init() {
        self.init(workspace: LibraryWorkspaceStore())
    }

    /// Siempre 5, ordenados. Si a la biblioteca le faltara alguno, se muestra vacío.
    var slots: [Slot] {
        let records = workspace.activeSlots()
        return (1...Self.slotCount).map { index in
            guard let record = records.first(where: { $0.order == index }) else {
                return Slot(index: index, label: "Slot \(index)", content: nil, cardBackgroundHex: nil)
            }
            return Slot(
                index: index,
                label: record.title,
                content: record.clipContent(),
                cardBackgroundHex: record.cardBackgroundHex
            )
        }
    }

    func slot(at index: Int) -> Slot? {
        slots.first { $0.index == index }
    }

    func updateLabel(index: Int, label: String) {
        workspace.updateActiveSlot(order: index) { $0.title = label }
    }

    func updateCardBackground(index: Int, hex: String?) {
        let stored = SlotsPalette.storedBackgroundHex(hex)
        workspace.updateActiveSlot(order: index) { $0.cardBackgroundHex = stored }
    }

    func saveContent(index: Int, content: ClipContent) {
        workspace.updateActiveSlot(order: index) { $0.setContent(content) }
    }

    func clearSlot(index: Int) {
        workspace.updateActiveSlot(order: index) { $0.setContent(nil) }
    }

    /// Intercambia el contenido entre dos slots. El número (y su atajo) no se mueve.
    func swapContents(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex else { return }
        let source = content(at: sourceIndex)
        let destination = content(at: destinationIndex)
        workspace.updateActiveSlot(order: sourceIndex) { $0.setContent(destination) }
        workspace.updateActiveSlot(order: destinationIndex) { $0.setContent(source) }
    }

    func content(at index: Int) -> ClipContent? {
        workspace.activeSlot(order: index)?.clipContent()
    }

    // MARK: - Testing helpers

    func replaceAll(_ newSlots: [Slot]) {
        for slot in newSlots {
            workspace.updateActiveSlot(order: slot.index) { record in
                record.title = slot.label
                record.cardBackgroundHex = slot.cardBackgroundHex
                record.setContent(slot.content)
            }
        }
    }
}
