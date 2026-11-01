import Foundation

enum SlotKind: String, Codable, Sendable, CaseIterable {
    case text
    case link
    case image
    case color
    case file
}

/// Biblioteca de slots (Trabajo, Personal, …).
struct Library: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var order: Int
    var createdAt: Date
    var updatedAt: Date

    static func defaults(now: Date = Date()) -> [Library] {
        [
            Library(id: UUID(uuidString: "A1000000-0000-4000-8000-000000000001")!, name: "Trabajo", order: 0, createdAt: now, updatedAt: now),
            Library(id: UUID(uuidString: "A1000000-0000-4000-8000-000000000002")!, name: "Personal", order: 1, createdAt: now, updatedAt: now),
            Library(id: UUID(uuidString: "A1000000-0000-4000-8000-000000000003")!, name: "Clientes", order: 2, createdAt: now, updatedAt: now),
        ]
    }
}

/// Slot persistido según `flujos.md` (macOS: 5 fijos por biblioteca).
struct SlotRecord: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var libraryId: UUID
    /// Posición 1…5 en Mac.
    var order: Int
    var title: String
    var kind: SlotKind
    var textPayload: String?
    var imageFileName: String?
    var linkURL: String?
    var meta: String?
    var createdAt: Date
    var updatedAt: Date

    func clipContent() -> ClipContent? {
        switch kind {
        case .text, .link, .color:
            guard let textPayload, !textPayload.isEmpty else { return nil }
            return .text(textPayload)
        case .image:
            guard let imageFileName else { return nil }
            return .image(fileName: imageFileName)
        case .file:
            guard let textPayload, !textPayload.isEmpty else { return nil }
            return .text(textPayload)
        }
    }
}

/// Historial del sistema (Mac).
struct HistoryRecord: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var sourceApp: String?
    var sourceBundleID: String?
    var copiedAt: Date
    var kind: SlotKind
    var textPayload: String?
    var imageFileName: String?
    var preview: String

    func clipItem() -> ClipItem? {
        let content: ClipContent?
        switch kind {
        case .image:
            guard let imageFileName else { return nil }
            content = .image(fileName: imageFileName)
        default:
            guard let textPayload else { return nil }
            content = .text(textPayload)
        }
        guard let content else { return nil }
        return ClipItem(
            id: id,
            content: content,
            createdAt: copiedAt,
            sourceAppName: sourceApp,
            sourceAppBundleID: sourceBundleID,
            isPinned: false
        )
    }
}

struct SlotsWorkspace: Codable, Equatable, Sendable {
    var libraries: [Library]
    var slots: [SlotRecord]
    var activeLibraryId: UUID
    var schemaVersion: Int = 1

    static func empty(now: Date = Date()) -> SlotsWorkspace {
        let libraries = Library.defaults(now: now)
        let active = libraries[0].id
        var slots: [SlotRecord] = []
        for library in libraries {
            for order in 1...SlotStore.slotCount {
                slots.append(
                    SlotRecord(
                        id: UUID(),
                        libraryId: library.id,
                        order: order,
                        title: "Slot \(order)",
                        kind: .text,
                        textPayload: nil,
                        imageFileName: nil,
                        linkURL: nil,
                        meta: nil,
                        createdAt: now,
                        updatedAt: now
                    )
                )
            }
        }
        return SlotsWorkspace(libraries: libraries, slots: slots, activeLibraryId: active)
    }
}
