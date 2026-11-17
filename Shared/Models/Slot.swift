import Foundation

/// Slot fijo numerado (1–5) con etiqueta y contenido opcional.
struct Slot: Codable, Identifiable, Equatable, Sendable {
    let index: Int
    var label: String
    var content: ClipContent?
    /// Fondo opcional de la card (hex paleta Slots).
    var cardBackgroundHex: String?

    var id: Int { index }

    static func defaultSlots() -> [Slot] {
        (1...SlotStore.slotCount).map { index in
            Slot(index: index, label: "Slot \(index)", content: nil, cardBackgroundHex: nil)
        }
    }

    func matchesSearch(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        if label.localizedCaseInsensitiveContains(q) { return true }
        if let content { return content.matchesSearch(q) }
        return false
    }
}
