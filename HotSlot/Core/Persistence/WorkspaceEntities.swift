import Foundation
import SwiftData

// Modelos que viajan por iCloud (CloudKit, base privada).
// Reglas de CloudKit: todo con valor por defecto u opcional, sin unicidad y sin relaciones.
// Por eso el slot apunta a su biblioteca por `libraryId` y los duplicados se fusionan a mano (ver `WorkspaceDatabase`).
// No viajan: la ruta y el bookmark de archivos, la biblioteca activa, los ajustes ni el historial.

@Model
final class LibraryEntity {
    var uuid: UUID = UUID()
    var name: String = ""
    var order: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(from library: Library) {
        uuid = library.id
        name = library.name
        order = library.order
        createdAt = library.createdAt
        updatedAt = library.updatedAt
    }

    func apply(_ library: Library) {
        name = library.name
        order = library.order
        createdAt = library.createdAt
        updatedAt = library.updatedAt
    }

    var library: Library {
        Library(id: uuid, name: name, order: order, createdAt: createdAt, updatedAt: updatedAt)
    }
}

@Model
final class SlotEntity {
    var uuid: UUID = UUID()
    var libraryId: UUID = UUID()
    var order: Int = 1
    var title: String = ""
    var kindRaw: String = SlotKind.text.rawValue
    var textPayload: String?
    var linkURL: String?
    var meta: String?
    var cardBackgroundHex: String?
    var imageFileName: String?
    /// Los bytes de la imagen: CloudKit los sube como archivo aparte.
    @Attribute(.externalStorage) var imageData: Data?
    /// Nombre visible de un archivo guardado. La ruta se queda en el Mac.
    var fileName: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(from record: SlotRecord) {
        uuid = record.id
        apply(record)
    }

    /// Copia los campos del slot. La imagen se lee del disco solo si cambió.
    func apply(_ record: SlotRecord) {
        libraryId = record.libraryId
        order = record.order
        title = record.title
        kindRaw = record.kind.rawValue
        textPayload = record.textPayload
        linkURL = record.linkURL
        meta = record.meta
        cardBackgroundHex = record.cardBackgroundHex
        createdAt = record.createdAt
        updatedAt = record.updatedAt
        fileName = record.fileName ?? record.filePath.map { ($0 as NSString).lastPathComponent }

        if record.imageFileName != imageFileName || (record.imageFileName != nil && imageData == nil) {
            imageFileName = record.imageFileName
            imageData = record.imageFileName.flatMap {
                try? Data(contentsOf: AppSupportDirectory.images.appendingPathComponent($0))
            }
        }
    }
}
