import SwiftUI

/// Estado del resplandor que rodea el notch mientras se espera para abrir la barra.
@MainActor @Observable
final class NotchGlowModel {
    var progress: Double = 0
    var neckWidth: CGFloat = 200
    var neckHeight: CGFloat = 32
}

/// Sombreado alrededor del notch: crece durante la espera y muestra que «algo está pasando»
/// hasta que se abre la barra. Misma sombra cálida que el hover del resto de la app.
struct NotchHoverGlowView: View {
    static let margin: CGFloat = 40

    @Bindable var model: NotchGlowModel

    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 14,
            bottomTrailingRadius: 14,
            topTrailingRadius: 0,
            style: .continuous
        )
        let p = model.progress

        ZStack(alignment: .top) {
            // Sombra ancha y suave.
            shape.stroke(Color(slotsHex: 0x462D14).opacity(0.5), lineWidth: 8)
                .blur(radius: 6 + 8 * p)
            // Borde cálido más cerca del notch.
            shape.stroke(SlotsColor.naranja.opacity(0.55), lineWidth: 3)
                .blur(radius: 2 + 3 * p)
        }
        .frame(width: model.neckWidth, height: model.neckHeight)
        .opacity(p)
        .padding(.horizontal, Self.margin)
        .padding(.bottom, Self.margin)
        .frame(
            width: model.neckWidth + Self.margin * 2,
            height: model.neckHeight + Self.margin,
            alignment: .top
        )
        .allowsHitTesting(false)
    }
}
