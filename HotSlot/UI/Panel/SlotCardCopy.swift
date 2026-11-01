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
        }
    }

    static func metaLine(for slot: Slot) -> String {
        "\(metaPrimary(for: slot))\n\(metaSecondary(for: slot))"
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
