import Foundation
import SwiftUI

enum SlotCardCopy {
    static func metaPrimary(for slot: Slot) -> String {
        "Slot \(slot.index)"
    }

    static func metaSecondary(for slot: Slot) -> String {
        guard let content = slot.content else {
            return "Vacío"
        }
        switch content {
        case .text(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if isHexColor(trimmed) {
                return "Color"
            }
            if trimmed.lowercased().hasPrefix("http"), let host = URL(string: trimmed)?.host {
                return host
            }
            let words = trimmed.split { $0.isWhitespace || $0.isNewline }.count
            return "Texto · \(words) palabras"
        case .image:
            return "Imagen"
        case .file:
            return content.typeLabel
        }
    }

    static func metaLine(for slot: Slot) -> String {
        "\(metaPrimary(for: slot))\n\(metaSecondary(for: slot))"
    }

    /// Texto inicial al renombrar (lo que ve el usuario en la card, en una línea).
    static func editableTitle(for slot: Slot) -> String {
        displayTitle(for: slot)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func slotLabelDisplay(for slot: Slot) -> String {
        let label = slot.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !label.isEmpty, label != "Slot \(slot.index)" {
            return label
        }
        return "Slot \(slot.index)"
    }

    /// Título visible: el nombre custom gana siempre, incluso si el slot está vacío.
    static func visibleCardTitle(for slot: Slot) -> String {
        if hasCustomLabel(slot) { return slotLabelDisplay(for: slot) }
        if slot.content == nil { return emptyPlaceholderTitle(for: slot) }
        return slotLabelDisplay(for: slot)
    }

    static func hasCustomLabel(_ slot: Slot) -> Bool {
        let label = slot.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return !label.isEmpty && label != "Slot \(slot.index)"
    }

    /// Al editar, el placeholder de vacío no se mete en el campo.
    static func editingTitle(for slot: Slot) -> String {
        hasCustomLabel(slot) ? slotLabelDisplay(for: slot) : "Slot \(slot.index)"
    }

    static func emptyPlaceholderTitle(for slot: Slot) -> String {
        if slot.index == 5 { return "Soltá algo acá" }
        if slot.index == 1 { return "Tu primer slot" }
        return "Slot \(slot.index)"
    }

    /// Texto del cuerpo de la card (contenido real, no metadatos).
    static func contentBodyPreview(for slot: Slot) -> String? {
        guard let content = slot.content else { return nil }
        switch content {
        case .text(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if isHexColor(trimmed) { return normalizedHex(trimmed) }
            return trimmed
        case .image, .file:
            return nil
        }
    }

    static func displayTitle(for slot: Slot) -> String {
        let label = slot.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !label.isEmpty, label != "Slot \(slot.index)" {
            return label
        }
        if slot.content == nil {
            if slot.index == 5 {
                return "Soltá\nalgo acá"
            }
            if slot.index == 1 {
                return "Tu primer\nslot"
            }
            return "Slot \(slot.index)"
        }
        if let content = slot.content, case .text(let string) = content, isHexColor(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return normalizedHex(string)
        }
        return label.isEmpty ? "Slot \(slot.index)" : label
    }

    static func emptySubhint(slotIndex: Int) -> String? {
        guard slotIndex == 5 else { return nil }
        return "o guardá con ⌘⌃W"
    }

    static func emptyHint(slotIndex: Int) -> String {
        let letters = ["A", "S", "D", "Q", "W"]
        let letter = letters.indices.contains(slotIndex - 1) ? letters[slotIndex - 1] : "A"
        if slotIndex == 1 {
            return "Arrastrá del historial o guardá con ⌘⌃\(letter)"
        }
        return "Soltá algo acá · o guardá con ⌘⌃\(letter)"
    }

    static func isHexColor(_ string: String) -> Bool {
        let pattern = #"^#?[0-9A-Fa-f]{6}$"#
        return string.range(of: pattern, options: .regularExpression) != nil
    }

    static func normalizedHex(_ string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("#") ? trimmed.uppercased() : "#\(trimmed.uppercased())"
    }

    static func colorFromHex(_ string: String) -> Color? {
        guard isHexColor(string) else { return nil }
        var hex = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard let value = UInt32(hex, radix: 16) else { return nil }
        return Color(slotsHex: value)
    }
}
