import CoreData
import Foundation
import SwiftData

/// Guarda bibliotecas y slots en SwiftData y los sincroniza con iCloud (CloudKit, base privada).
/// La UI sigue trabajando con `SlotsWorkspace`: esta clase solo lo convierte de ida y vuelta.
@MainActor
final class WorkspaceDatabase {
    static let cloudContainerID = "iCloud.com.hotslot.app"

    /// Se llama cuando llegan cambios de otro dispositivo.
    var onRemoteChange: (() -> Void)?

    /// `false` en tests: base local, sin iCloud.
    let syncsWithCloud: Bool

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private var remoteObserver: NSObjectProtocol?
    private var cloudEventObserver: NSObjectProtocol?
    private var importFinished = false
    private var importWaiters: [() -> Void] = []

    /// `nil` si la base no se pudo abrir: el llamador sigue con el JSON de siempre.
    init?() {
        let schema = Schema([LibraryEntity.self, SlotEntity.self])
        let url = AppSupportDirectory.root.appendingPathComponent("Workspace.store")
        // Tests: base local, sin tocar iCloud.
        let syncs = AppSupportDirectory.rootOverride == nil
        syncsWithCloud = syncs
        let cloud: ModelConfiguration.CloudKitDatabase = syncs ? .private(Self.cloudContainerID) : .none
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: cloud)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            NSLog("Slots: no se pudo abrir la base de SwiftData: \(error)")
            return nil
        }
        remoteObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onRemoteChange?() }
        }
        if syncs {
            // Avisa cuando termina el primer import desde iCloud.
            cloudEventObserver = NotificationCenter.default.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event,
                      event.type == .import, event.endDate != nil else { return }
                Task { @MainActor in self?.markImportFinished() }
            }
        }
    }

    deinit {
        if let remoteObserver { NotificationCenter.default.removeObserver(remoteObserver) }
        if let cloudEventObserver { NotificationCenter.default.removeObserver(cloudEventObserver) }
    }

    private func markImportFinished() {
        importFinished = true
        let waiters = importWaiters
        importWaiters = []
        waiters.forEach { $0() }
    }

    /// Espera a que termine el primer import desde iCloud, o hasta `timeout` segundos (sin conexión, sin cuenta…).
    func waitForFirstImport(timeout: TimeInterval) async {
        guard syncsWithCloud, !importFinished else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var resumed = false
            let resume = {
                guard !resumed else { return }
                resumed = true
                continuation.resume()
            }
            importWaiters.append(resume)
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { resume() }
        }
    }

    // MARK: - Lectura

    /// El workspace guardado, o `nil` si la base está vacía.
    /// Antes de armarlo fusiona duplicados (mismo id, o dos slots en la misma posición): gana el más reciente.
    func load() -> SlotsWorkspace? {
        mergeDuplicates()

        let libraries = ((try? context.fetch(FetchDescriptor<LibraryEntity>())) ?? []).map(\.library)
        guard !libraries.isEmpty else { return nil }
        let libraryIds = Set(libraries.map(\.id))

        let slotEntities = (try? context.fetch(FetchDescriptor<SlotEntity>())) ?? []
        let fileRefs = LocalFileReferences.load()
        var slots: [SlotRecord] = []
        for entity in slotEntities where libraryIds.contains(entity.libraryId) {
            restoreImageIfNeeded(entity)
            let reference = fileRefs[entity.uuid]
            slots.append(
                SlotRecord(
                    id: entity.uuid,
                    libraryId: entity.libraryId,
                    order: entity.order,
                    title: entity.title,
                    kind: SlotKind(rawValue: entity.kindRaw) ?? .text,
                    textPayload: entity.textPayload,
                    imageFileName: entity.imageFileName,
                    linkURL: entity.linkURL,
                    meta: entity.meta,
                    filePath: reference?.path,
                    fileBookmark: reference?.bookmark,
                    cardBackgroundHex: entity.cardBackgroundHex,
                    createdAt: entity.createdAt,
                    updatedAt: entity.updatedAt
                )
            )
        }

        let active = LocalFileReferences.activeLibraryId()
        let activeId = active.flatMap { id in libraries.contains { $0.id == id } ? id : nil }
            ?? libraries.sorted { $0.order < $1.order }[0].id
        return SlotsWorkspace(libraries: libraries, slots: slots, activeLibraryId: activeId)
    }

    // MARK: - Escritura

    /// Deja la base igual al workspace: crea lo nuevo, actualiza lo que cambió y borra lo que ya no está.
    func write(_ workspace: SlotsWorkspace) {
        var libraryEntities = Dictionary(
            ((try? context.fetch(FetchDescriptor<LibraryEntity>())) ?? []).map { ($0.uuid, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for library in workspace.libraries {
            if let entity = libraryEntities.removeValue(forKey: library.id) {
                if entity.library != library { entity.apply(library) }
            } else {
                context.insert(LibraryEntity(from: library))
            }
        }
        for stale in libraryEntities.values { context.delete(stale) }

        var slotEntities = Dictionary(
            ((try? context.fetch(FetchDescriptor<SlotEntity>())) ?? []).map { ($0.uuid, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var references: [UUID: LocalFileReferences.Reference] = [:]
        for record in workspace.slots {
            if let path = record.filePath {
                references[record.id] = .init(path: path, bookmark: record.fileBookmark)
            }
            if let entity = slotEntities.removeValue(forKey: record.id) {
                if entity.updatedAt != record.updatedAt || entity.libraryId != record.libraryId
                    || entity.order != record.order || entity.title != record.title
                    || entity.cardBackgroundHex != record.cardBackgroundHex {
                    entity.apply(record)
                }
            } else {
                context.insert(SlotEntity(from: record))
            }
        }
        for stale in slotEntities.values { context.delete(stale) }

        LocalFileReferences.save(references)
        LocalFileReferences.setActiveLibraryId(workspace.activeLibraryId)
        try? context.save()
    }

    // MARK: - Fusión de duplicados

    /// CloudKit no garantiza unicidad: dos dispositivos pueden crear la misma biblioteca o el mismo slot.
    private func mergeDuplicates() {
        var changed = false

        let libraries = (try? context.fetch(FetchDescriptor<LibraryEntity>())) ?? []
        for group in Dictionary(grouping: libraries, by: \.uuid).values where group.count > 1 {
            let keep = group.max { $0.updatedAt < $1.updatedAt }
            for entity in group where entity !== keep { context.delete(entity); changed = true }
        }

        let slots = (try? context.fetch(FetchDescriptor<SlotEntity>())) ?? []
        var survivors: [SlotEntity] = []
        for group in Dictionary(grouping: slots, by: \.uuid).values {
            let keep = group.max { $0.updatedAt < $1.updatedAt }
            for entity in group {
                if entity === keep { survivors.append(entity) } else { context.delete(entity); changed = true }
            }
        }
        struct Position: Hashable { let libraryId: UUID; let order: Int }
        for group in Dictionary(grouping: survivors, by: { Position(libraryId: $0.libraryId, order: $0.order) }).values
        where group.count > 1 {
            let keep = group.max { $0.updatedAt < $1.updatedAt }
            for entity in group where entity !== keep { context.delete(entity); changed = true }
        }

        if changed { try? context.save() }
    }

    /// Un slot que llegó de otro dispositivo trae los bytes de la imagen pero no el archivo en este Mac.
    private func restoreImageIfNeeded(_ entity: SlotEntity) {
        guard let name = entity.imageFileName, let data = entity.imageData else { return }
        let url = AppSupportDirectory.images.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// Datos que se quedan en este Mac: la ruta de los archivos guardados y la biblioteca activa.
enum LocalFileReferences {
    struct Reference: Codable, Equatable {
        var path: String
        var bookmark: Data?
    }

    private static let activeLibraryKey = "slots.activeLibraryId"

    private static var file: URL {
        AppSupportDirectory.root.appendingPathComponent("local-file-references.json")
    }

    static func load() -> [UUID: Reference] {
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode([UUID: Reference].self, from: data) else { return [:] }
        return decoded
    }

    static func save(_ references: [UUID: Reference]) {
        guard load() != references, let data = try? JSONEncoder().encode(references) else { return }
        try? data.write(to: file, options: .atomic)
    }

    static func activeLibraryId() -> UUID? {
        UserDefaults.standard.string(forKey: activeLibraryKey).flatMap(UUID.init(uuidString:))
    }

    static func setActiveLibraryId(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: activeLibraryKey)
    }
}
