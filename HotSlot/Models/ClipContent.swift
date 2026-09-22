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

    var isText: Bool {
        if case .text = self { return true }
        return false
    }
}
