import AppKit
import QuartzCore
import SwiftUI

/// Constantes de diseño compartidas (estilo Clipboard nativo de macOS).
enum HotSlotDesign {
    static let panelWidth: CGFloat = 1060
    static let panelHeight: CGFloat = 664
    /// Pista bajo el panel (handoff: fuera de la tarjeta de vidrio).
    static let panelHintOutsideGap: CGFloat = 12
    static let panelHintOutsideHeight: CGFloat = 22
    /// Franja bajo la tarjeta: pista de uso, o el tacho mientras se arrastra una biblioteca.
    static let panelBottomBandHeight: CGFloat = 64
    static var panelWindowHeight: CGFloat {
        panelHeight + panelHintOutsideGap + panelBottomBandHeight
    }
    /// Separación vertical entre cabecera, cuerpo y barra (handoff `Main.html` gap 24).
    static let panelSectionGap: CGFloat = SlotsSpace.l
    static let panelBodyGap: CGFloat = SlotsSpace.l
    static let historyColumnWidth: CGFloat = 330
    /// Altura aproximada de cabecera (animación de apertura); el layout usa tamaño intrínseco + `panelSectionGap`.
    static let panelHeaderHeight: CGFloat = 112
    /// Alineación óptica entre grilla e historial (misma línea superior de columna).
    static let panelColumnTopInset: CGFloat = 2
    static let panelSearchFieldWidth: CGFloat = 300
    static let cornerRadius: CGFloat = SlotsRadius.ventana
    static let cardCornerRadius: CGFloat = SlotsRadius.card
    static let horizontalPadding: CGFloat = SlotsSpace.paddingPanel
    static let thumbnailCornerRadius: CGFloat = 8
    static let rowHeight: CGFloat = 52
    static let imageRowPreviewWidth: CGFloat = 128
    static let imageRowPreviewHeight: CGFloat = 76
    static let imageRowPreviewMaxExpandedHeight: CGFloat = 240
    static let textRowPreviewHeight: CGFloat = 48
    static let textRowPreviewHeightExpanded: CGFloat = 176
    static let hoverExpandDelay: TimeInterval = 0.42
    /// Altura visual compartida: «Slot N», atajo y cruz en la card.
    static let slotHeaderChipHeight: CGFloat = 20
    static let slotHeaderChipMinWidth: CGFloat = 28
    /// Altura fija de la fila del título en cards (evita saltos al editar / lápiz).
    static let slotTitleRowHeight: CGFloat = 46
    static let shortcutBadgeWidthRegular: CGFloat = 62

    static let titleEditAnimation = Animation.easeInOut(duration: 0.22)

    static let openDuration: TimeInterval = 0.16
    static let closeDuration: TimeInterval = 0.16
    static let springTiming = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
    static let closeTiming = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.6, 1.0)
    static let openRightDuration: TimeInterval = 0.08

    static let closeScaleInset: CGFloat = 14
    static let openSlideOffset: CGFloat = 28
    static let closeSlideOffset: CGFloat = 16
    static let openSquareSize: CGFloat = panelHeaderHeight
}

/// Elevación al pasar el mouse, común al panel y a la barra del notch.
/// `scales` agranda un 2 %: para slots, pills y botones; no para filas densas del historial.
struct SlotsHoverLift: ViewModifier {
    var isActive: Bool
    var scales = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(scales && isActive ? 1.02 : 1)
            .shadow(
                color: Color(slotsHex: 0x462D14).opacity(isActive ? 0.32 : 0),
                radius: isActive ? 14 : 0,
                y: isActive ? 6 : 0
            )
    }
}

/// Un slot acaba de recibir contenido (o nacer): un «pop» breve con un halo cálido que se apaga.
/// Lo usan el panel y el notch para que el aviso de guardado se sienta igual en los dos.
struct SlotArrivalEffect: ViewModifier {
    let isActive: Bool
    @State private var progress: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(1 + 0.05 * progress)
            .shadow(color: SlotsColor.naranja.opacity(0.5 * progress), radius: 16 * progress)
            .onAppear { if isActive { play() } }
            .onChange(of: isActive) { _, active in if active { play() } }
    }

    private func play() {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.55)) { progress = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.55)) { progress = 0 }
        }
    }
}

/// Entrada de un slot nuevo: crece desde un poco más chico mientras aparece.
extension AnyTransition {
    static var slotArrival: AnyTransition {
        .scale(scale: 0.82).combined(with: .opacity)
    }
}

extension View {
    func slotArrival(_ isActive: Bool) -> some View {
        modifier(SlotArrivalEffect(isActive: isActive))
    }

    func slotsHoverLift(_ isActive: Bool, scales: Bool = false) -> some View {
        modifier(SlotsHoverLift(isActive: isActive, scales: scales))
    }
}

/// Contenedor del panel con material nativo.
/// El frame externo es siempre el del panel completo (evita que NSHostingView redimensione la ventana).
struct PanelChrome<Content: View>: View {
    var revealWidth: CGFloat = HotSlotDesign.panelWidth
    var revealHeight: CGFloat = HotSlotDesign.panelHeight
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: HotSlotDesign.cornerRadius, style: .continuous)

        ZStack(alignment: .topLeading) {
            ZStack {
                SlotsColor.vidrioTinte
                VisualEffectBackground(
                    material: .hudWindow,
                    blendingMode: .withinWindow,
                    cornerRadius: HotSlotDesign.cornerRadius
                )
                .opacity(0.85)
            }
            content()
                .frame(
                    width: HotSlotDesign.panelWidth,
                    height: HotSlotDesign.panelHeight,
                    alignment: .topLeading
                )
        }
        .frame(width: revealWidth, height: revealHeight, alignment: .topLeading)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(Color.white.opacity(0.75), lineWidth: 1)
        }
        .frame(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelHeight, alignment: .topLeading)
        .contentShape(shape)
    }
}

/// Botón cuadrado redondeado (pin, vaciar slot).
struct PanelGlyphButton: View {
    let systemImage: String
    var foreground: Color = .secondary
    var help: String?
    var size: CGFloat = 28
    var iconSize: CGFloat = 12
    var cornerRadius: CGFloat = 8
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(isHovering ? 0.12 : 0.07))
                }
        }
        .buttonStyle(.plain)
        .help(help ?? "")
        .onHover { isHovering = $0 }
    }
}
