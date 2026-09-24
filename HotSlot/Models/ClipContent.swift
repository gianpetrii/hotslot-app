import Foundation

/// Contenido almacenable de un clip o slot.
enum ClipContent: Codable, Equatable, Sendable {
    case text(String)
    case image(fileName: String)

    var previewText: String {
        switch self {
        case .text(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "Texto vacío" }
            let singleLine = trimmed.replacingOccurrences(of: "\n", with: " ")
            return singleLine.count > 80 ? String(singleLine.prefix(80)) + "…" : singleLine
        case .image:
            return "Imagen"
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
        }
    }

    var typeLabel: String {
        switch self {
        case .text: return "Texto"
        case .image(let fileName):
            let ext = (fileName as NSString).pathExtension.uppercased()
            return ext.isEmpty ? "Imagen" : "\(ext) image"
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
    func metadataLine(locale: Locale = .current) -> String {
        let time = createdAt.formatted(date: .omitted, time: .shortened)
        let copied = "Copiado \(time)"
        if let app = sourceAppName {
            return "\(content.typeLabel) · \(app) · \(copied)"
        }
        return "\(content.typeLabel) · \(copied)"
    }

    func matchesSearch(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        return content.matchesSearch(q)
            || (sourceAppName?.localizedCaseInsensitiveContains(q) ?? false)
    }
}
