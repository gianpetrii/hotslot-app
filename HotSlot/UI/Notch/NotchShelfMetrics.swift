import CoreGraphics
import Foundation

/// Medidas de la barra del notch, tomadas de los tokens del panel (`SlotsSpace`, `SlotsRadius`).
enum NotchShelfMetrics {
    /// Cards apaisadas: mantienen el ancho y bajan el alto para que la barra sea menos invasiva.
    static let tileWidth: CGFloat = 128
    static let tileHeight: CGFloat = 88
    static let tileCorner: CGFloat = SlotsRadius.card
    static let gap: CGFloat = SlotsSpace.entreCards
    static let pad: CGFloat = SlotsSpace.l
    /// Columna de la derecha con las flechas de página.
    static let pagerWidth: CGFloat = 32
    static let padVertical: CGFloat = 18
    static let sectionGap: CGFloat = 12
    static let libraryHeight: CGFloat = SlotsRadius.controlAlto
    static let shelfCorner: CGFloat = SlotsRadius.ventana
    static let shadowPad: CGFloat = 44
    /// Slots por página en la barra.
    static let pageSize = 5
    /// Cierre más ágil que el del panel: la barra sobra rápido al sacar el mouse.
    static let closeDuration: TimeInterval = 0.1
    static let hideDelay: TimeInterval = 0.04

    static let contentWidth: CGFloat  = pad * 2 + tileWidth * 5 + gap * 4 + gap + pagerWidth
    static let contentHeight: CGFloat = padVertical + tileHeight + sectionGap + libraryHeight + padVertical

    static let panelWidth: CGFloat  = contentWidth  + shadowPad * 2
    /// Franja bajo la barra para el tacho que aparece al arrastrar una biblioteca.
    static let trashZone: CGFloat = 60
    /// Lugar para el cuello que sube hasta el borde de la pantalla (la barra de menú mide menos que esto).
    static let topAllowance: CGFloat = 48
    static let panelHeight: CGFloat = contentHeight + topAllowance + shadowPad + trashZone
}
