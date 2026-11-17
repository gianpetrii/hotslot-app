import UIKit
import UniformTypeIdentifiers

/// Lee el portapapeles del iPhone. Leer muestra el aviso de pegado del sistema, así que solo se llama
/// cuando la persona toca «Usar», «Reemplazar» o «Pegar portapapeles». `hasContent` no lo muestra.
enum ClipboardReader {
    /// Hay algo copiado. No lee el contenido ni dispara el aviso del sistema.
    static var hasContent: Bool {
        let pasteboard = UIPasteboard.general
        return pasteboard.hasStrings || pasteboard.hasURLs || pasteboard.hasImages
    }

    static func read() -> ClipContent? {
        let pasteboard = UIPasteboard.general
        if pasteboard.hasImages, let image = pasteboard.image, let content = SlotFiles.saveImage(image) {
            return content
        }
        if pasteboard.hasURLs, let url = pasteboard.url, !url.isFileURL {
            return .text(url.absoluteString)
        }
        if let string = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
            return .text(string)
        }
        return nil
    }
}

/// Guarda en el contenedor de la app las imágenes y archivos que van a un slot.
enum SlotFiles {
    static func saveImage(_ image: UIImage) -> ClipContent? {
        guard let data = image.pngData() else { return nil }
        return saveImage(data: data, fileExtension: "png")
    }

    /// PNG, JPEG y GIF se guardan tal cual; el resto (HEIC, etc.) pasa a JPEG para que se pueda pegar en cualquier app.
    static func saveImage(data: Data, type: UTType?) -> ClipContent? {
        if let type, let ext = type.preferredFilenameExtension,
           type.conforms(to: .png) || type.conforms(to: .jpeg) || type.conforms(to: .gif) {
            return saveImage(data: data, fileExtension: ext)
        }
        guard let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.92) else { return nil }
        return saveImage(data: jpeg, fileExtension: "jpg")
    }

    private static func saveImage(data: Data, fileExtension: String) -> ClipContent? {
        let name = "\(UUID().uuidString).\(fileExtension)"
        let url = AppSupportDirectory.images.appendingPathComponent(name)
        guard (try? data.write(to: url, options: .atomic)) != nil else { return nil }
        return .image(fileName: name)
    }

    /// Copia el archivo elegido al contenedor. Solo el nombre viaja por iCloud.
    static func importFile(from url: URL) -> ClipContent? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let folder = AppSupportDirectory.files.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destination = folder.appendingPathComponent(url.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: destination)
        } catch {
            return nil
        }
        return .file(path: destination.path, bookmark: nil)
    }
}
