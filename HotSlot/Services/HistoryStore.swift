import Foundation

/// Almacén del historial de clipboard en JSON local.
@MainActor
@Observable
final class HistoryStore {
    private(set) var items: [ClipItem] = []
    var historyLimit: Int = AppSettings.load().historyLimit

    init() {
        load()
    }

    func add(_ item: ClipItem) {
        // Deduplicar: quitar ítem previo con mismo fingerprint
        items.removeAll { $0.contentFingerprint == item.contentFingerprint }
        items.insert(item, at: 0)

        if items.count > historyLimit {
            items = Array(items.prefix(historyLimit))
        }
        save()
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    func contains(fingerprint: String) -> Bool {
        items.contains { $0.contentFingerprint == fingerprint }
    }

    private func load() {
        guard let data = try? Data(contentsOf: AppSupportDirectory.historyFile),
              let decoded = try? JSONDecoder().decode([ClipItem].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: AppSupportDirectory.historyFile, options: .atomic)
    }

    // MARK: - Testing helpers

    func replaceAll(_ newItems: [ClipItem]) {
        items = newItems
        save()
    }
}
