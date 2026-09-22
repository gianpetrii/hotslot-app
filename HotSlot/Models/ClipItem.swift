import CryptoKit
import Foundation

/// Ítem del historial de clipboard.
struct ClipItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let content: ClipContent
    let createdAt: Date
    let sourceAppName: String?
    let sourceAppBundleID: String?

    init(
        id: UUID = UUID(),
        content: ClipContent,
        createdAt: Date = Date(),
        sourceAppName: String? = nil,
        sourceAppBundleID: String? = nil
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.sourceAppName = sourceAppName
        self.sourceAppBundleID = sourceAppBundleID
    }

    /// Hash estable para deduplicación (basado en contenido real, no en nombre de archivo).
    var contentFingerprint: String {
        switch content {
        case .text(let string):
            return "text:" + Self.sha256(string)
        case .image(let fileName):
            let url = AppSupportDirectory.images.appendingPathComponent(fileName)
            if let data = try? Data(contentsOf: url) {
                return "image:" + Self.sha256(data)
            }
            return "image:\(fileName)"
        }
    }

    private static func sha256(_ string: String) -> String {
        sha256(Data(string.utf8))
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
