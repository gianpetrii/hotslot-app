import Foundation

/// Almacén del historial de clipboard en JSON local.
@MainActor
@Observable
final class HistoryStore {
    private(set) var items: [ClipItem] = []
    var historyLimit: Int = AppSettings.load().historyLimit
    private var persistChanges = true

    init(loadPersisted: Bool = true) {
        if loadPersisted {
            load()
        }
    }

    /// Datos en memoria para el tour; no lee ni escribe disco.
    static func preview(items: [ClipItem]) -> HistoryStore {
        let store = HistoryStore(loadPersisted: false)
        store.items = items
        store.persistChanges = false
        return store
    }

    func add(_ item: ClipItem) {
        if let index = items.firstIndex(where: { $0.contentFingerprint == item.contentFingerprint }) {
            let existing = items[index]
            let updated = ClipItem(
                id: existing.id,
                content: item.content,
                createdAt: item.createdAt,
                sourceAppName: item.sourceAppName,
                sourceAppBundleID: item.sourceAppBundleID,
                isPinned: existing.isPinned
            )
            if existing.isPinned {
                items[index] = updated
            } else {
                items.remove(at: index)
                items.insert(updated, at: firstUnpinnedIndex)
            }
        } else {
            items.insert(item, at: firstUnpinnedIndex)
        }
        trimToLimit()
        save()
    }

    func item(id: UUID) -> ClipItem? {
        items.first { $0.id == id }
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func togglePin(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: index)
        item.isPinned.toggle()
        items.insert(item, at: firstUnpinnedIndex)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        let pins = items.filter(\.isPinned)
        let rest = items.filter { !$0.isPinned }
        items = pins + rest
        save()
    }

    func moveItem(id: UUID, before destinationID: UUID) {
        guard id != destinationID,
              let from = items.firstIndex(where: { $0.id == id }),
              let to = items.firstIndex(where: { $0.id == destinationID }) else { return }
        let dest = from < to ? to + 1 : to
        items.move(fromOffsets: IndexSet(integer: from), toOffset: dest)
        let pins = items.filter(\.isPinned)
        let rest = items.filter { !$0.isPinned }
        items = pins + rest
        save()
    }

    private var firstUnpinnedIndex: Int {
        items.firstIndex(where: { !$0.isPinned }) ?? items.count
    }

    private func trimToLimit() {
        guard items.count > historyLimit else { return }
        let pins = items.filter(\.isPinned)
        let rest = items.filter { !$0.isPinned }
        let room = max(0, historyLimit - pins.count)
        items = pins + Array(rest.prefix(room))
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
        guard persistChanges else { return }
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: AppSupportDirectory.historyFile, options: .atomic)
    }

    // MARK: - Testing helpers

    func replaceAll(_ newItems: [ClipItem]) {
        items = newItems
        save()
    }
}
