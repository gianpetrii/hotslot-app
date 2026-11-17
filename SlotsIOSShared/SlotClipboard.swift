import UIKit
import UniformTypeIdentifiers

/// Copia el contenido de un slot al portapapeles del iPhone. Copiar no pide permiso.
enum SlotClipboard {
    /// `false` si el slot está vacío o su archivo no está en este dispositivo.
    @discardableResult
    static func copy(_ slot: SlotRecord) -> Bool {
        guard let content = slot.clipContent() else { return false }
        let pasteboard = UIPasteboard.general
        switch content {
        case .text(let string):
            if slot.kind == .link, let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
               url.scheme != nil {
                // Como link y como texto: cada app toma lo que entiende.
                pasteboard.setItems([[
                    UTType.url.identifier: url,
                    UTType.utf8PlainText.identifier: string,
                ]])
            } else {
                pasteboard.string = string
            }
            return true
        case .image:
            guard let url = content.imageURL, let data = try? Data(contentsOf: url) else { return false }
            // Los bytes originales, sin recomprimir.
            let type = UTType(filenameExtension: url.pathExtension) ?? .png
            pasteboard.setData(data, forPasteboardType: type.identifier)
            return true
        case .file:
            guard let url = content.resolvedFileURL, let provider = NSItemProvider(contentsOf: url) else { return false }
            provider.suggestedName = url.lastPathComponent
            pasteboard.setItemProviders([provider], localOnly: false, expirationDate: nil)
            return true
        }
    }
}
