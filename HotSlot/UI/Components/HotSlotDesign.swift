import AppKit
import QuartzCore
import SwiftUI

/// Constantes de diseño compartidas (estilo Spotlight / macOS nativo).
enum HotSlotDesign {
    static let panelWidth: CGFloat = 460
    static let panelHeight: CGFloat = 540
    static let cornerRadius: CGFloat = 22
    static let cardCornerRadius: CGFloat = 14
    static let rowCornerRadius: CGFloat = 12
    static let horizontalPadding: CGFloat = 18
    static let sectionSpacing: CGFloat = 12

    static let openDuration: TimeInterval = 0.32
    static let closeDuration: TimeInterval = 0.22
    static let springTiming = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)

    static let openScaleInset: CGFloat = 24
    static let closeScaleInset: CGFloat = 18
}

/// Tipografía del sistema (SF Pro).
enum HotSlotTypography {
    static let panelTitle = Font.system(.title3, design: .default, weight: .semibold)
    static let panelSubtitle = Font.system(.caption, design: .default)
    static let sectionTitle = Font.system(.subheadline, design: .default, weight: .semibold)
    static let rowPrimary = Font.system(.callout, design: .default)
    static let rowSecondary = Font.system(.caption, design: .default)
    static let badge = Font.system(.caption, design: .default, weight: .medium)
    static let slotLabel = Font.system(.caption, design: .default, weight: .medium)
    static let slotPreview = Font.system(.caption2, design: .default)
}

/// Contenedor con borde sutil y sombra tipo Spotlight.
struct PanelChrome<Content: View>: View {
    @State private var isRevealed = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .popover, blendingMode: .behindWindow)
            content()
                .opacity(isRevealed ? 1 : 0)
                .offset(y: isRevealed ? 0 : 8)
        }
        .frame(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelHeight)
        .clipShape(RoundedRectangle(cornerRadius: HotSlotDesign.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HotSlotDesign.cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        }
        .shadow(color: .black.opacity(0.35), radius: 40, y: 18)
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                isRevealed = true
            }
        }
        .onDisappear {
            isRevealed = false
        }
    }
}

/// Fondo tipo tarjeta inset (slots, filas).
struct GlassCardBackground: View {
    var isHighlighted: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
            .fill(.thinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(isHighlighted ? 0.32 : 0.14), lineWidth: 0.5)
            }
    }
}

/// Título de sección del panel.
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(HotSlotTypography.sectionTitle)
            .foregroundStyle(.secondary)
            .padding(.horizontal, HotSlotDesign.horizontalPadding)
    }
}
