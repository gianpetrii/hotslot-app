import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let hotslotPanelDrag = UTType(exportedAs: "com.hotslot.panel-drag")
}

/// Payload de drag del panel: intercambiar slots o guardar un clip del historial.
enum PanelDragPayload: Codable, Transferable {
    case slot(index: Int)
    case historyItem(id: UUID)

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .hotslotPanelDrag)
    }
}
