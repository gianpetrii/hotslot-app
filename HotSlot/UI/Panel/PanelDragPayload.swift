import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Slots e historial (intercambiar / guardar en slot).
    static let hotslotPanelDrag = UTType(exportedAs: "com.hotslot.panel-drag")
    /// Marca extra que solo lleva el arrastre de un slot: permite reconocerlo al soltar sin esperar a leer los datos.
    static let hotslotSlotDrag = UTType(exportedAs: "com.hotslot.slot-drag")
}

/// Payload de drag del panel: intercambiar slots o guardar un clip del historial.
enum PanelDragPayload: Codable, Transferable {
    /// `libraryId` es la biblioteca de la que sale el slot (el panel puede cambiar de biblioteca mientras se arrastra).
    case slot(index: Int, libraryId: UUID)
    case historyItem(id: UUID)

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .hotslotPanelDrag)
    }
}
