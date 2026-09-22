import AppKit
import CryptoKit
import UniformTypeIdentifiers

/// Utilidades para leer y escribir NSPasteboard.
enum PasteboardHelper {
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    private static let textTypes: [NSPasteboard.PasteboardType] = [
        .string,
        .rtf,
        .html,
        NSPasteboard.PasteboardType("public.utf8-plain-text"),
        NSPasteboard.PasteboardType("NSStringPboardType"),
    ]

    private static let imageTypes: [NSPasteboard.PasteboardType] = [
        .png,
        .tiff,
        NSPasteboard.PasteboardType("public.png"),
        NSPasteboard.PasteboardType("public.tiff"),
    ]

    static func shouldIgnore(pasteboard: NSPasteboard = .general) -> Bool {
        let types = pasteboard.types ?? []
        if types.contains(concealedType) { return true }
        if types.contains(transientType) { return true }
        return false
    }

    /// Clasifica el contenido actual del pasteboard.
    static func readContent(from pasteboard: NSPasteboard = .general) -> ClipContent? {
        if shouldIgnore(pasteboard: pasteboard) { return nil }

        let declaredTypes = Set(pasteboard.types ?? [])

        // Si hay tipos de texto declarados, nunca leer imagen (evita datos viejos de TIFF)
        if declaredTypes.contains(where: { textTypes.contains($0) }) {
            if let text = readText(from: pasteboard, declaredTypes: declaredTypes) {
                return .text(text)
            }
            return nil
        }

        if declaredTypes.contains(where: { imageTypes.contains($0) }) {
            return readImage(from: pasteboard)
        }

        return nil
    }

    @discardableResult
    static func write(content: ClipContent, to pasteboard: NSPasteboard = .general) -> Int {
        pasteboard.clearContents()

        switch content {
        case .text(let string):
            pasteboard.setString(string, forType: .string)
        case .image(let fileName):
            let url = AppSupportDirectory.images.appendingPathComponent(fileName)
            if let data = try? Data(contentsOf: url) {
                if fileName.hasSuffix(".png") {
                    pasteboard.setData(data, forType: .png)
                } else {
                    pasteboard.setData(data, forType: .tiff)
                }
            }
        }

        return pasteboard.changeCount
    }

    static func loadImage(named fileName: String) -> NSImage? {
        let url = AppSupportDirectory.images.appendingPathComponent(fileName)
        return NSImage(contentsOf: url)
    }

    @discardableResult
    static func copyContentToPasteboard(_ content: ClipContent) -> Int {
        write(content: content)
    }

    // MARK: - Lectura privada

    private static func readText(
        from pasteboard: NSPasteboard,
        declaredTypes: Set<NSPasteboard.PasteboardType>
    ) -> String? {
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return string }
        }

        if declaredTypes.contains(.rtf),
           let data = pasteboard.data(forType: .rtf),
           let attributed = NSAttributedString(rtf: data, documentAttributes: nil) {
            let plain = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !plain.isEmpty { return attributed.string }
        }

        if declaredTypes.contains(.html),
           let data = pasteboard.data(forType: .html),
           let attributed = NSAttributedString(html: data, documentAttributes: nil) {
            let plain = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !plain.isEmpty { return attributed.string }
        }

        return nil
    }

    /// Normaliza a PNG para hash estable y evitar duplicados por distinto encoding TIFF.
    private static func readImage(from pasteboard: NSPasteboard) -> ClipContent? {
        guard let image = NSImage(pasteboard: pasteboard),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        let fileName = saveImageData(png, extension: "png")
        return .image(fileName: fileName)
    }

    private static func saveImageData(_ data: Data, extension ext: String) -> String {
        let hash = SHA256.hash(data: data)
            .prefix(12)
            .map { String(format: "%02x", $0) }
            .joined()
        let fileName = "\(hash).\(ext)"
        let url = AppSupportDirectory.images.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? data.write(to: url)
        }
        return fileName
    }
}
