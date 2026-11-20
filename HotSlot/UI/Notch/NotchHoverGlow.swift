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
    static let margin: CGFloat = 56

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
            // Halo ancho y cálido: es lo que se nota a simple vista.
            shape.stroke(SlotsColor.naranja.opacity(0.65), lineWidth: 16)
                .blur(radius: 10 + 10 * p)
            // Sombra oscura para que también se vea sobre fondos claros.
            shape.stroke(Color(slotsHex: 0x462D14).opacity(0.55), lineWidth: 10)
                .blur(radius: 6 + 6 * p)
            // Borde nítido pegado al notch.
            shape.stroke(SlotsColor.naranja.opacity(0.95), lineWidth: 3)
                .blur(radius: 1 + 2 * p)
        }
        // Un poco más grande que el notch, para que el borde asome a los costados y abajo.
        .frame(width: model.neckWidth + 6, height: model.neckHeight + 3)
        .opacity(min(1, p * 1.4))
        .padding(.horizontal, Self.margin)
        .padding(.bottom, Self.margin)
        .frame(
            width: model.neckWidth + 6 + Self.margin * 2,
            height: model.neckHeight + 3 + Self.margin,
            alignment: .top
        )
        .allowsHitTesting(false)
    }
}
