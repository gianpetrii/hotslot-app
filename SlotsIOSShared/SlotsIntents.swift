import AppIntents
import Foundation
import SwiftUI
import WidgetKit

/// Lectura de solo lectura de las bibliotecas y slots, para atajos, controles y widgets.
/// Abre la misma base del App Group sin iCloud y sin escribir nada.
@MainActor
enum WorkspaceSnapshot {
    static func load() -> SlotsWorkspace? {
        WorkspaceDatabase(syncsWithCloud: false)?.load(mergingDuplicates: false)
    }

    static func sortedLibraries(_ workspace: SlotsWorkspace) -> [Library] {
        workspace.libraries.sorted { $0.order < $1.order }
    }

    static func sortedSlots(in libraryId: UUID, _ workspace: SlotsWorkspace) -> [SlotRecord] {
        workspace.slots.filter { $0.libraryId == libraryId }.sorted { $0.order < $1.order }
    }
}

// MARK: - Entidades

/// Un slot con contenido, para elegirlo en Atajos, controles y widgets.
struct SlotAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Slot")
    static let defaultQuery = SlotEntityQuery()

    var id: UUID
    var title: String
    var libraryName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(libraryName)")
    }

    /// Slot que no existe: lo usa el control sin configurar.
    static let missing = SlotAppEntity(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, title: "Elegir slot", libraryName: "")

    init(id: UUID, title: String, libraryName: String) {
        self.id = id
        self.title = title
        self.libraryName = libraryName
    }

    init(_ record: SlotRecord, libraryName: String) {
        let title = record.title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(id: record.id, title: title.isEmpty ? "Slot \(record.order)" : title, libraryName: libraryName)
    }

    /// Todos los slots con contenido, por biblioteca y posición.
    @MainActor static func all() -> [SlotAppEntity] {
        guard let workspace = WorkspaceSnapshot.load() else { return [] }
        return WorkspaceSnapshot.sortedLibraries(workspace).flatMap { library in
            WorkspaceSnapshot.sortedSlots(in: library.id, workspace)
                .filter { $0.clipContent() != nil }
                .map { SlotAppEntity($0, libraryName: library.name) }
        }
    }
}

struct SlotEntityQuery: EntityQuery, EntityStringQuery {
    @MainActor func entities(for identifiers: [UUID]) async throws -> [SlotAppEntity] {
        SlotAppEntity.all().filter { identifiers.contains($0.id) }
    }

    @MainActor func entities(matching string: String) async throws -> [SlotAppEntity] {
        SlotAppEntity.all().filter {
            $0.title.localizedCaseInsensitiveContains(string) || $0.libraryName.localizedCaseInsensitiveContains(string)
        }
    }

    @MainActor func suggestedEntities() async throws -> [SlotAppEntity] {
        SlotAppEntity.all()
    }
}

/// Una biblioteca, para elegirla en el widget.
struct LibraryAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Biblioteca")
    static let defaultQuery = LibraryEntityQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    @MainActor static func all() -> [LibraryAppEntity] {
        guard let workspace = WorkspaceSnapshot.load() else { return [] }
        return WorkspaceSnapshot.sortedLibraries(workspace).map { LibraryAppEntity(id: $0.id, name: $0.name) }
    }
}

struct LibraryEntityQuery: EntityQuery {
    @MainActor func entities(for identifiers: [UUID]) async throws -> [LibraryAppEntity] {
        LibraryAppEntity.all().filter { identifiers.contains($0.id) }
    }

    @MainActor func suggestedEntities() async throws -> [LibraryAppEntity] {
        LibraryAppEntity.all()
    }
}

// MARK: - Intents

/// «Abrir Slots»: para Atajos, Siri, Spotlight, Back Tap, el Botón de Acción y el Centro de Control.
struct OpenSlotsIntent: AppIntent {
    static let title: LocalizedStringResource = "Abrir Slots"
    static let description = IntentDescription("Abre Slots para ver todos tus slots.")
    static let openAppWhenRun = true

    init() {}

    func perform() async throws -> some IntentResult {
        .result()
    }
}

/// «Copiar slot»: copia el slot elegido al portapapeles sin abrir la app.
struct CopySlotIntent: AppIntent {
    static let title: LocalizedStringResource = "Copiar slot"
    static let description = IntentDescription("Copia un slot al portapapeles para pegarlo en otra app.")

    @Parameter(title: "Slot")
    var slot: SlotAppEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Copiar \(\.$slot)")
    }

    init() {}

    init(slot: SlotAppEntity) {
        self.slot = slot
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let workspace = WorkspaceSnapshot.load(),
              let record = workspace.slots.first(where: { $0.id == slot.id }) else {
            return .result(dialog: "Ese slot ya no existe.", view: CopiedSnippetView(label: "No se pudo copiar", detail: "Ese slot ya no existe", isError: true))
        }
        if record.clipContent()?.isRemoteOnlyFile == true {
            return .result(dialog: "Ese archivo está solo en otro dispositivo.", view: CopiedSnippetView(label: "No se pudo copiar", detail: "Solo en otro dispositivo", isError: true))
        }
        guard SlotClipboard.copy(record) else {
            return .result(dialog: "No se pudo copiar.", view: CopiedSnippetView(label: "No se pudo copiar", detail: slot.title, isError: true))
        }
        return .result(dialog: "Copiado", view: CopiedSnippetView(label: "Copiado", detail: slot.title, isError: false))
    }
}

/// Tarjeta que muestra Atajos al copiar: la misma del aviso «Copiado» de la app.
struct CopiedSnippetView: View {
    let label: String
    let detail: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isError ? "exclamationmark" : "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isError ? Color(red: 0.77, green: 0.15, blue: 0.1) : Color(red: 0.89, green: 0.31, blue: 0.11))
                .frame(width: 28, height: 28)
                .background(.white, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.custom("InterTight-SemiBold", size: 16))
                Text(detail).font(.custom("InterTight-Medium", size: 14)).opacity(0.8).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(isError ? Color(red: 0.17, green: 0.17, blue: 0.17) : Color(red: 0.89, green: 0.31, blue: 0.11),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(8)
    }
}

/// Copia desde un widget sin abrir la app. Deja marcado qué slot se tocó para que el widget muestre «Copiado».
struct CopySlotFromWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Copiar slot desde el widget"
    static let isDiscoverable = false

    /// Dónde se anota el último slot copiado desde un widget (App Group).
    static let copiedKey = "widget.lastCopied"

    @Parameter(title: "Slot")
    var slot: SlotAppEntity

    init() {}

    init(slot: SlotAppEntity) {
        self.slot = slot
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let workspace = WorkspaceSnapshot.load(),
           let record = workspace.slots.first(where: { $0.id == slot.id }),
           record.clipContent()?.isRemoteOnlyFile != true,
           SlotClipboard.copy(record) {
            UserDefaults(suiteName: AppSupportDirectory.appGroupID)?
                .set("\(slot.id.uuidString)|\(Date().timeIntervalSince1970)", forKey: Self.copiedKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
