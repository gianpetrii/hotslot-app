import CryptoKit
import Foundation

/// Ítem del historial de clipboard.
struct ClipItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let content: ClipContent
    let createdAt: Date
    let sourceAppName: String?
    let sourceAppBundleID: String?
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        content: ClipContent,
        createdAt: Date = Date(),
        sourceAppName: String? = nil,
        sourceAppBundleID: String? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.sourceAppName = sourceAppName
        self.sourceAppBundleID = sourceAppBundleID
        self.isPinned = isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(ClipContent.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
        sourceAppBundleID = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleID)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
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

    private enum CodingKeys: String, CodingKey {
        case id, content, createdAt, sourceAppName, sourceAppBundleID, isPinned
    }
}
