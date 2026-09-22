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

    /// Hash estable para deduplicación.
    var contentFingerprint: String {
        switch content {
        case .text(let string):
            return "text:\(string)"
        case .image(let fileName):
            return "image:\(fileName)"
        }
    }
}
