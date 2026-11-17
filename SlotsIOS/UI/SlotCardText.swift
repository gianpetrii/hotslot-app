import SwiftUI

/// Textos de una card de slot: el tipo, el dato y el título.
enum SlotCardText {
    /// Primera línea: el tipo de contenido.
    static func kindLabel(_ slot: SlotRecord) -> String {
        guard let content = slot.clipContent() else { return "Slot \(slot.order)" }
        switch content {
        case .text(let string):
            if hexColor(string) != nil { return "Color" }
            return slot.kind == .link ? "Link" : "Texto"
        case .image: return "Imagen"
        case .file: return content.isFolder ? "Carpeta" : "Archivo"
        }
    }

    /// Segunda línea: dominio, cantidad de palabras, medidas, etc.
    static func detail(_ slot: SlotRecord) -> String {
        guard let content = slot.clipContent() else { return "Vacío" }
        switch content {
        case .text(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let hex = hexColor(trimmed) { return hex }
            if slot.kind == .link, let host = URL(string: trimmed)?.host {
                return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            }
            let words = trimmed.split { $0.isWhitespace || $0.isNewline }.count
            return words == 1 ? "1 palabra" : "\(words) palabras"
        case .image(let fileName):
            guard let size = SlotImageLoader.pixelSize(fileName: fileName) else { return "" }
            return "\(Int(size.width)) × \(Int(size.height))"
        case .file:
            return content.fileDetail
        }
    }

    static func title(_ slot: SlotRecord) -> String {
        let title = slot.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Slot \(slot.order)" : title
    }

    /// El nombre que le puso la persona, o `nil` si sigue con el de arranque («Slot 3»).
    static func customTitle(_ slot: SlotRecord) -> String? {
        let title = slot.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty || title == "Slot \(slot.order)" ? nil : title
    }

    /// `#RRGGBB` normalizado si el texto es un color hex.
    static func hexColor(_ string: String) -> String? { HexColor.normalized(string) }
}
