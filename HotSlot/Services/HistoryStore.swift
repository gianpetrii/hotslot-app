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
        var newItem = item
        if let existing = items.first(where: { $0.contentFingerprint == item.contentFingerprint }) {
            newItem.isPinned = existing.isPinned
        }

        items.removeAll { $0.contentFingerprint == item.contentFingerprint }

        if newItem.isPinned {
            items.insert(newItem, at: 0)
        } else {
            let insertIndex = items.firstIndex(where: { !$0.isPinned }) ?? items.count
            items.insert(newItem, at: insertIndex)
        }

        if items.count > historyLimit {
            items = Array(items.prefix(historyLimit))
        }
        save()
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func togglePin(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: index)
        item.isPinned.toggle()

        if item.isPinned {
            items.insert(item, at: 0)
        } else {
            let insertIndex = items.firstIndex(where: { !$0.isPinned }) ?? items.count
            items.insert(item, at: insertIndex)
        }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
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
