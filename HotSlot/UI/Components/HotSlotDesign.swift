import SwiftUI

/// Constantes de diseño compartidas (estilo macOS nativo).
enum HotSlotDesign {
    static let panelWidth: CGFloat = 440
    static let panelHeight: CGFloat = 520
    static let cornerRadius: CGFloat = 18
    static let cardCornerRadius: CGFloat = 12
    static let rowCornerRadius: CGFloat = 10
    static let horizontalPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 10
}

/// Contenedor con borde sutil y sombra tipo Control Center.
struct PanelChrome<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            VisualEffectBackground()
            content()
        }
        .frame(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelHeight)
        .clipShape(RoundedRectangle(cornerRadius: HotSlotDesign.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HotSlotDesign.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.28), radius: 28, y: 14)
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
                    .strokeBorder(Color.white.opacity(isHighlighted ? 0.28 : 0.12), lineWidth: 0.5)
            }
    }
}

/// Título de sección del panel.
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
            .padding(.horizontal, HotSlotDesign.horizontalPadding)
    }
}
