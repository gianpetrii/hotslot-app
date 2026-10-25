import AppKit
import QuartzCore
import SwiftUI

/// Constantes de diseño compartidas (estilo Clipboard nativo de macOS).
enum HotSlotDesign {
    static let panelWidth: CGFloat = 572
    static let panelHeight: CGFloat = 520
    static let panelHeaderHeight: CGFloat = 58
    static let panelBodyHeight: CGFloat = panelHeight - panelHeaderHeight
    static let slotsColumnWidth: CGFloat = 176
    static let cornerRadius: CGFloat = 16
    static let cardCornerRadius: CGFloat = 10
    static let rowCornerRadius: CGFloat = 10
    static let horizontalPadding: CGFloat = 12
    static let sectionSpacing: CGFloat = 10
    static let thumbnailSize: CGFloat = 44
    static let thumbnailCornerRadius: CGFloat = 8
    static let rowHeight: CGFloat = 52
    static let imageRowPreviewWidth: CGFloat = 128
    static let imageRowPreviewHeight: CGFloat = 76
    static let imageRowPreviewHeightExpanded: CGFloat = 148
    static let imageRowPreviewMaxExpandedHeight: CGFloat = 240
    static let textRowPreviewHeight: CGFloat = 48
    static let textRowPreviewHeightExpanded: CGFloat = 176
    static let hoverExpandDelay: TimeInterval = 0.42
    static let slotPeekWidth: CGFloat = 268
    static let slotPeekImageHeight: CGFloat = 168
    static let slotPeekMaxTextHeight: CGFloat = 220
    static let slotPeekHideDelay: TimeInterval = 0.18
    static let slotOverlayControlSize: CGFloat = 22
    static let slotOverlayIconSize: CGFloat = 10
    static let slotOverlayCornerRadius: CGFloat = 6
    /// Ancho fijo del badge de atajo (evita que el popover se mueva al grabar/borrar).
    static let shortcutBadgeWidthCompact: CGFloat = 50
    static let shortcutBadgeWidthRegular: CGFloat = 56
    static let onboardingWidth: CGFloat = 460
    static let onboardingHeight: CGFloat = 560

    static let rowExpandAnimation = Animation.spring(response: 0.32, dampingFraction: 0.92)

    static let openDuration: TimeInterval = 0.4
    static let closeDuration: TimeInterval = 0.28
    static let springTiming = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
    static let closeTiming = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.6, 1.0)
    /// Expandir a la derecha (cuadrado → barra de búsqueda).
    static let openRightTiming = CAMediaTimingFunction(controlPoints: 0.16, 1.18, 0.28, 1.0)
    /// Expandir hacia abajo (barra → panel completo).
    static let openDownTiming = CAMediaTimingFunction(controlPoints: 0.2, 1.08, 0.32, 1.0)
    static let openRightDuration: TimeInterval = 0.42
    static let openDownDuration: TimeInterval = 0.48

    static let openScaleInset: CGFloat = 20
    static let closeScaleInset: CGFloat = 14
    static let openSlideOffset: CGFloat = 28
    static let closeSlideOffset: CGFloat = 16
    static let openSquareSize: CGFloat = panelHeaderHeight
}

/// Tipografía alineada al Clipboard de macOS (SF Pro).
enum HotSlotTypography {
    static let searchField = Font.system(size: 15, weight: .regular)
    static let sectionTitle = Font.system(size: 11, weight: .semibold)
    static let rowPrimary = Font.system(size: 13, weight: .regular)
    static let rowSecondary = Font.system(size: 11, weight: .regular)
    static let slotShortcut = Font.system(size: 9, weight: .medium)
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
            VisualEffectBackground(
                material: .menu,
                blendingMode: .behindWindow,
                cornerRadius: HotSlotDesign.cornerRadius
            )
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
            shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
        .frame(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelHeight, alignment: .topLeading)
        .contentShape(shape)
    }
}

/// Título de sección discreto.
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(HotSlotTypography.sectionTitle)
            .foregroundStyle(.tertiary)
            .tracking(0.4)
            .padding(.horizontal, HotSlotDesign.horizontalPadding)
    }
}

/// Botón circular de acción en filas (estilo Clipboard).
struct RowActionButton: View {
    let systemImage: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(Color.primary.opacity(isHovering ? 0.1 : 0.06))
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                        }
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
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
