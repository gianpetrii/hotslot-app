import Foundation

/// Archivos y carpetas guardados como referencia (ruta + bookmark).
extension ClipContent {
    /// Ruta ficticia de un archivo que solo está en otro dispositivo: nunca existe, y tras ella va el nombre.
    static let remoteOnlyPathPrefix = "/@solo-en-otro-dispositivo/"

    /// El slot llegó por iCloud con el nombre del archivo, pero el archivo está en otro dispositivo.
    var isRemoteOnlyFile: Bool {
        guard case .file(let path, _) = self else { return false }
        return path.hasPrefix(Self.remoteOnlyPathPrefix)
    }

    /// Referencia a `url`. El bookmark permite encontrarlo si se renombra o se mueve.
    static func fileReference(url: URL) -> ClipContent {
        let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        return .file(path: url.path, bookmark: bookmark)
    }

    /// Dónde está hoy el archivo: la ruta guardada o, si ya no está ahí, la que resuelve el bookmark.
    var resolvedFileURL: URL? {
        guard case .file(let path, let bookmark) = self else { return nil }
        if FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        guard let bookmark else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withoutUI, .withoutMounting],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// Es un archivo cuya ruta ya no existe. El resto de los contenidos nunca está "perdido".
    var isMissingFile: Bool {
        guard case .file = self else { return false }
        return resolvedFileURL == nil
    }

    var fileName: String {
        guard case .file(let path, _) = self else { return "" }
        return (resolvedFileURL ?? URL(fileURLWithPath: path)).lastPathComponent
    }

    var isFolder: Bool {
        guard let url = resolvedFileURL else { return false }
        return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    /// «PDF · 2,4 MB», «Carpeta» o «No encontrado».
    var fileDetail: String {
        guard case .file = self else { return "" }
        if isRemoteOnlyFile { return "Solo en otro dispositivo" }
        guard let url = resolvedFileURL else { return "No encontrado" }
        if isFolder { return "Carpeta" }
        let ext = url.pathExtension.uppercased()
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map {
            ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)
        }
        switch (ext.isEmpty, size) {
        case (false, let size?): return "\(ext) · \(size)"
        case (false, nil): return ext
        case (true, let size?): return size
        case (true, nil): return "Archivo"
        }
    }
}
