import AppKit
import CryptoKit
import UniformTypeIdentifiers

/// Utilidades para leer y escribir NSPasteboard.
enum PasteboardHelper {
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    static func shouldIgnore(pasteboard: NSPasteboard = .general) -> Bool {
        let types = pasteboard.types ?? []
        if types.contains(concealedType) { return true }
        if types.contains(transientType) { return true }
        return false
    }

    /// Clasifica el contenido actual del pasteboard.
    static func readContent(from pasteboard: NSPasteboard = .general) -> ClipContent? {
        if shouldIgnore(pasteboard: pasteboard) { return nil }

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            return .text(string)
        }

        if let tiff = pasteboard.data(forType: .tiff) {
            let fileName = saveImageData(tiff, extension: "tiff")
            return .image(fileName: fileName)
        }

        if let png = pasteboard.data(forType: .png) {
            let fileName = saveImageData(png, extension: "png")
            return .image(fileName: fileName)
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

    private static func saveImageData(_ data: Data, extension ext: String) -> String {
        let hash = SHA256.hash(data: data)
            .prefix(8)
            .map { String(format: "%02x", $0) }
            .joined()
        let fileName = "\(hash).\(ext)"
        let url = AppSupportDirectory.images.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? data.write(to: url)
        }
        return fileName
    }

    /// Copia un ClipContent al pasteboard reutilizando archivos de imagen existentes.
    static func copyContentToPasteboard(_ content: ClipContent) -> Int {
        write(content: content)
    }
}
