import Foundation

enum SlotCardCopy {
    static func metaLine(for slot: Slot) -> String {
        guard let content = slot.content else {
            return "Slot \(slot.index) · Vacío"
        }
        switch content {
        case .text(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().hasPrefix("http"), let host = URL(string: trimmed)?.host {
                return "Link · \(host)"
            }
            let words = trimmed.split { $0.isWhitespace || $0.isNewline }.count
            return "Texto · \(words) palabras"
        case .image:
            return "Imagen"
        }
    }

    static func displayTitle(for slot: Slot) -> String {
        let label = slot.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !label.isEmpty, label != "Slot \(slot.index)" {
            return label
        }
        if slot.content == nil {
            if slot.index == 1 {
                return "Tu primer slot"
            }
            return "Slot \(slot.index)"
        }
        return label.isEmpty ? "Slot \(slot.index)" : label
    }

    static func emptyHint(slotIndex: Int) -> String {
        let letters = ["A", "S", "D", "Q", "W"]
        let letter = letters.indices.contains(slotIndex - 1) ? letters[slotIndex - 1] : "A"
        if slotIndex == 1 {
            return "Arrastrá del historial o guardá con ⌘⌃\(letter)"
        }
        return "Soltá algo acá · o guardá con ⌘⌃\(letter)"
    }
}
