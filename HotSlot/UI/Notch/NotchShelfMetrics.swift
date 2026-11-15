import CoreGraphics
import Foundation

/// Medidas de la barra del notch, tomadas de los tokens del panel (`SlotsSpace`, `SlotsRadius`).
enum NotchShelfMetrics {
    static let tile: CGFloat = 128
    static let tileCorner: CGFloat = SlotsRadius.card
    static let gap: CGFloat = SlotsSpace.entreCards
    static let pad: CGFloat = SlotsSpace.l
    static let sectionGap: CGFloat = SlotsSpace.m
    static let libraryHeight: CGFloat = SlotsRadius.controlAlto
    static let shelfCorner: CGFloat = SlotsRadius.ventana
    static let shadowPad: CGFloat = 44
    /// Slots por página en la barra.
    static let pageSize = 5
    /// Cierre más ágil que el del panel: la barra sobra rápido al sacar el mouse.
    static let closeDuration: TimeInterval = 0.1
    static let hideDelay: TimeInterval = 0.04

    static let contentWidth: CGFloat  = pad * 2 + tile * 5 + gap * 4
    static let contentHeight: CGFloat = pad + tile + sectionGap + libraryHeight + pad

    static let panelWidth: CGFloat  = contentWidth  + shadowPad * 2
    static let panelHeight: CGFloat = contentHeight + shadowPad * 2
}
