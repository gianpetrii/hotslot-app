import Foundation

/// Los slots de la biblioteca activa. Los primeros 5 tienen atajo.
/// No guarda nada propio: lee y escribe directamente en el workspace, que es la única fuente de verdad.
@MainActor
@Observable
final class SlotStore {
    /// Cuántos slots tienen atajo (por posición). Una biblioteca puede tener más.
    static let slotCount = 5

    private let workspace: LibraryWorkspaceStore

    init(workspace: LibraryWorkspaceStore) {
        self.workspace = workspace
    }

    /// Para pruebas: un workspace propio que carga desde el disco.
    convenience init() {
        self.init(workspace: LibraryWorkspaceStore())
    }

    /// Los 5 slots con atajo, ordenados. Si a la biblioteca le faltara alguno, se muestra vacío.
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

    /// Todos los slots de la biblioteca activa, ordenados por posición.
    var allSlots: [Slot] {
        workspace.activeSlots().map { record in
            Slot(
                index: record.order,
                label: record.title,
                content: record.clipContent(),
                cardBackgroundHex: record.cardBackgroundHex
            )
        }
    }

    var totalSlotCount: Int { workspace.slotCount(in: workspace.workspace.activeLibraryId) }

    /// Agrega un slot al final de la biblioteca activa. Devuelve su posición.
    @discardableResult
    func addSlot(content: ClipContent? = nil) -> Int? {
        workspace.addSlot(toLibraryId: workspace.workspace.activeLibraryId, content: content)
    }

    @discardableResult
    func removeSlot(index: Int) -> Bool {
        workspace.removeSlot(libraryId: workspace.workspace.activeLibraryId, order: index)
    }

    /// Mueve el slot a otra posición; los demás se corren.
    @discardableResult
    func moveSlot(from: Int, to: Int) -> Bool {
        workspace.moveSlot(libraryId: workspace.workspace.activeLibraryId, from: from, to: to)
    }

    /// Intercambia dos slots completos; el resto queda igual.
    @discardableResult
    func swapSlots(_ a: Int, _ b: Int) -> Bool {
        workspace.swapSlots(libraryId: workspace.workspace.activeLibraryId, a, b)
    }

    func slot(at index: Int) -> Slot? {
        allSlots.first { $0.index == index }
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
