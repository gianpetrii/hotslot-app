import Foundation

/// Contenido almacenable de un clip o slot.
enum ClipContent: Codable, Equatable, Sendable {
    case text(String)
    case image(fileName: String)
    /// Referencia a un archivo o carpeta. No se copia: se guarda la ruta y un bookmark para seguirlo si se mueve.
    case file(path: String, bookmark: Data?)

    /// Dos referencias son iguales si apuntan a la misma ruta (el bookmark cambia entre capturas).
    static func == (lhs: ClipContent, rhs: ClipContent) -> Bool {
        switch (lhs, rhs) {
        case let (.text(a), .text(b)): return a == b
        case let (.image(a), .image(b)): return a == b
        case let (.file(a, _), .file(b, _)): return a == b
        default: return false
        }
    }

    var previewText: String {
        switch self {
        case .text(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "Texto vacío" }
            let singleLine = trimmed.replacingOccurrences(of: "\n", with: " ")
            return singleLine.count > 80 ? String(singleLine.prefix(80)) + "…" : singleLine
        case .image:
            return "Imagen"
        case .file:
            return fileName
        }
    }

    var displayTitle: String {
        switch self {
        case .text(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "Texto vacío" }
            let singleLine = trimmed.replacingOccurrences(of: "\n", with: " ")
            return singleLine.count > 60 ? String(singleLine.prefix(60)) + "…" : singleLine
        case .image(let fileName):
            let ext = (fileName as NSString).pathExtension.uppercased()
            if ext.isEmpty { return "Imagen" }
            return "Imagen.\(ext.lowercased())"
        case .file:
            return fileName
        }
    }

    var typeLabel: String {
        switch self {
        case .text: return "Texto"
        case .image(let fileName):
            let ext = (fileName as NSString).pathExtension.uppercased()
            return ext.isEmpty ? "Imagen" : "Imagen \(ext)"
        case .file:
            if isFolder { return "Carpeta" }
            let ext = (fileName as NSString).pathExtension.uppercased()
            return ext.isEmpty ? "Archivo" : "Archivo \(ext)"
        }
    }

    var imageURL: URL? {
        guard case .image(let fileName) = self else { return nil }
        return AppSupportDirectory.images.appendingPathComponent(fileName)
    }

    var isText: Bool {
        if case .text = self { return true }
        return false
    }

    func matchesSearch(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return displayTitle.lowercased().contains(q)
            || previewText.lowercased().contains(q)
            || typeLabel.lowercased().contains(q)
    }
}

extension ClipItem {
    func copiedLine() -> String {
        let time = createdAt.formatted(date: .omitted, time: .shortened)
        let when: String
        if Calendar.current.isDateInToday(createdAt) {
            when = "Copiado \(time)"
        } else if Calendar.current.isDateInYesterday(createdAt) {
            when = "Ayer \(time)"
        } else {
            when = createdAt.formatted(date: .abbreviated, time: .shortened)
        }
        if let app = sourceAppName, !app.isEmpty {
            return "\(when) · \(app)"
        }
        return when
    }

    func metadataLine(locale: Locale = .current) -> String {
        "\(content.typeLabel) · \(copiedLine())"
    }

    func matchesSearch(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        return content.matchesSearch(q)
            || (sourceAppName?.localizedCaseInsensitiveContains(q) ?? false)
    }

    func handoffPanelMetaLine() -> String {
        let appName = sourceAppName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let app = (appName?.isEmpty == false) ? appName! : "Clipboard"
        return "\(app) · \(handoffRelativeTime())"
    }

    /// Conserva los saltos de línea; varias líneas en blanco seguidas se reducen a una.
    func handoffPanelPrimaryLine() -> String {
        switch content {
        case .text(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "Texto vacío" }
            return trimmed
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: #"\n[ \t]*\n(?:[ \t]*\n)+"#, with: "\n\n", options: .regularExpression)
        case .image, .file:
            return content.displayTitle
        }
    }

    private func handoffRelativeTime() -> String {
        let seconds = max(0, Date().timeIntervalSince(createdAt))
        if seconds < 45 { return "ahora" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "hace \(minutes) min" }
        let hours = minutes / 60
        if hours < 24 { return "hace \(hours) h" }
        return "hace \(hours / 24) d"
    }
}
