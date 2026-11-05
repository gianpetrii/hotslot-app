import CryptoKit
import Foundation

/// Formato original (RTF/HTML) de un texto copiado.
/// `ClipContent.text` guarda solo texto plano; el formato vive aparte, indexado por el texto,
/// así historial y slots lo comparten sin cambiar el modelo.
enum RichTextStore {
    struct Formats {
        var rtf: Data?
        var html: Data?
    }

    static func save(_ formats: Formats, for text: String) {
        guard formats.rtf != nil || formats.html != nil else {
            remove(for: text)
            return
        }
        write(formats.rtf, to: fileURL(for: text, ext: "rtf"))
        write(formats.html, to: fileURL(for: text, ext: "html"))
    }

    static func load(for text: String) -> Formats {
        Formats(
            rtf: try? Data(contentsOf: fileURL(for: text, ext: "rtf")),
            html: try? Data(contentsOf: fileURL(for: text, ext: "html"))
        )
    }

    static func remove(for text: String) {
        write(nil, to: fileURL(for: text, ext: "rtf"))
        write(nil, to: fileURL(for: text, ext: "html"))
    }

    private static func write(_ data: Data?, to url: URL) {
        if let data {
            try? data.write(to: url, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func fileURL(for text: String, ext: String) -> URL {
        let hash = SHA256.hash(data: Data(text.utf8))
            .prefix(16)
            .map { String(format: "%02x", $0) }
            .joined()
        return AppSupportDirectory.richText.appendingPathComponent("\(hash).\(ext)")
    }
}
