import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Slots e historial (intercambiar / guardar en slot).
    static let hotslotPanelDrag = UTType(exportedAs: "com.hotslot.panel-drag")
    /// Solo reordenar o eliminar bibliotecas (pills del footer).
    static let hotslotLibraryDrag = UTType(exportedAs: "com.hotslot.library-drag")
}

/// Payload de drag del panel: intercambiar slots o guardar un clip del historial.
enum PanelDragPayload: Codable, Transferable {
    case slot(index: Int)
    case historyItem(id: UUID)

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .hotslotPanelDrag)
    }
}

/// Arrastrar una pill de biblioteca (reorden / tacho).
struct LibraryDragPayload: Codable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .hotslotLibraryDrag)
    }
}
