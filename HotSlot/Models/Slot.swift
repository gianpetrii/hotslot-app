import Foundation

/// Slot fijo numerado (1–5) con etiqueta y contenido opcional.
struct Slot: Codable, Identifiable, Equatable, Sendable {
    let index: Int
    var label: String
    var content: ClipContent?

    var id: Int { index }

    static func defaultSlots() -> [Slot] {
        (1...SlotStore.slotCount).map { index in
            Slot(index: index, label: "Slot \(index)", content: nil)
        }
    }
}
