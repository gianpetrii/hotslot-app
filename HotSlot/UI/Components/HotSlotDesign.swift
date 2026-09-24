import AppKit
import QuartzCore
import SwiftUI

/// Constantes de diseño compartidas (estilo Clipboard nativo de macOS).
enum HotSlotDesign {
    static let panelWidth: CGFloat = 392
    static let panelHeight: CGFloat = 520
    static let panelHeaderHeight: CGFloat = 58
    static let panelBodyHeight: CGFloat = panelHeight - panelHeaderHeight
    static let cornerRadius: CGFloat = 16
    static let cardCornerRadius: CGFloat = 10
    static let rowCornerRadius: CGFloat = 10
    static let horizontalPadding: CGFloat = 12
    static let sectionSpacing: CGFloat = 10
    static let thumbnailSize: CGFloat = 44
    static let thumbnailCornerRadius: CGFloat = 8
    static let rowHeight: CGFloat = 56

    static let openDuration: TimeInterval = 0.4
    static let closeDuration: TimeInterval = 0.28
    static let springTiming = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
    static let closeTiming = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.6, 1.0)

    static let openScaleInset: CGFloat = 20
    static let closeScaleInset: CGFloat = 14
    static let openSlideOffset: CGFloat = 28
    static let closeSlideOffset: CGFloat = 16
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
struct PanelChrome<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            VisualEffectBackground(material: .menu, blendingMode: .behindWindow)
            content()
        }
        .frame(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelHeight, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: HotSlotDesign.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HotSlotDesign.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
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
