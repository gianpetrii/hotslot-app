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
    /// Usa el orden de tipos declarados (el primero es la representación principal).
    static func readContent(from pasteboard: NSPasteboard = .general) -> ClipContent? {
        if shouldIgnore(pasteboard: pasteboard) { return nil }

        let orderedTypes = pasteboard.types ?? []

        for type in orderedTypes {
            if textTypes.contains(type), let text = readText(from: pasteboard, preferredType: type) {
                return .text(text)
            }
            if imageTypes.contains(type), let image = readImage(from: pasteboard) {
                return image
            }
        }

        // Fallback: intentar texto e imagen sin depender del orden
        if let text = readText(from: pasteboard, preferredType: nil) {
            return .text(text)
        }
        if let image = readImage(from: pasteboard) {
            return image
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
        preferredType: NSPasteboard.PasteboardType?
    ) -> String? {
        let candidates: [NSPasteboard.PasteboardType] = if let preferredType {
            [preferredType]
        } else {
            textTypes
        }

        for type in candidates {
            switch type {
            case .string, NSPasteboard.PasteboardType("public.utf8-plain-text"), NSPasteboard.PasteboardType("NSStringPboardType"):
                if let string = pasteboard.string(forType: type) ?? pasteboard.string(forType: .string) {
                    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return string }
                }
            case .rtf:
                if let data = pasteboard.data(forType: .rtf),
                   let attributed = NSAttributedString(rtf: data, documentAttributes: nil) {
                    let plain = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !plain.isEmpty { return attributed.string }
                }
            case .html:
                if let data = pasteboard.data(forType: .html),
                   let attributed = NSAttributedString(html: data, documentAttributes: nil) {
                    let plain = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !plain.isEmpty { return attributed.string }
                }
            default:
                if let string = pasteboard.string(forType: type) {
                    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return string }
                }
            }
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
