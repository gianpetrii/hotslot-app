import SwiftUI

/// Pantalla de carga (handoff `00 · Carga`). Su primer cuadro es idéntico a `LaunchScreen.storyboard`:
/// si cambiás una medida acá, cambiala también allá y en `scripts/render-launch-card.swift`.
struct LoadingView: View {
    /// Al salir, el slot se achica y se funde.
    var isLeaving: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    private static let cardSize = CGSize(width: 196, height: 236)
    private static let canvasSize = CGSize(width: 436, height: 476)
    /// El logo ocupa 116 pt sobre un viewBox de 34.
    private static let logoUnit: CGFloat = 116 / 34

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                SlotsColor.tinta

                Image("DegradeNaranja")
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width * 1.75, height: size.width * 1.75 * 1192 / 665)
                    .scaleEffect(animating ? 1.05 : 1)
                    .offset(y: animating ? -12 : 0)
                    .position(x: size.width * 0.5 * 0.2949, y: size.height * 0.5 * 0.5877)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 7).repeatForever(autoreverses: true), value: animating)

                card
                    .offset(y: animating ? -6 : 0)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: animating)
                    .scaleEffect(isLeaving ? 0.9 : 1)
                    .opacity(isLeaving ? 0 : 1)
                    .position(x: size.width / 2, y: size.height / 2)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .onAppear { animating = true }
        .accessibilityElement()
        .accessibilityLabel("Slots")
    }

    /// El slot de vidrio: la imagen base y, encima, el cuadradito naranja que «respira».
    private var card: some View {
        let margin = (Self.canvasSize.width - Self.cardSize.width) / 2
        let unit = Self.logoUnit
        return Image("LaunchCardBase")
            .resizable()
            .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4 * unit, style: .circular)
                    .fill(SlotsColor.naranja)
                    .frame(width: 14 * unit, height: 13 * unit)
                    .opacity(animating && !reduceMotion ? 0.55 : 1)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animating)
                    .offset(x: margin + 20 + 18 * unit, y: margin + 28 + 19 * unit)
            }
    }
}
