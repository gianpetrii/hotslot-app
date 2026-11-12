import SwiftUI

extension Color {
    init(slotsHex hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum SlotsColor {
    static let naranja = Color(slotsHex: 0xE2501D)
    static let tinta = Color(slotsHex: 0x111111)
    static let oxido = Color(slotsHex: 0xA8431A)
    static let arena = Color(slotsHex: 0xE7DED2)
    static let papel = Color(slotsHex: 0xF2F2F0)
    /// Fondo predeterminado de las cards de slot.
    static let piedra = Color(slotsHex: 0xE6E3DE)
    static let cardOscura = Color(slotsHex: 0x1C1C1C)
    static let textoSecundario = Color(slotsHex: 0x5E5A56)
    static let textoTerciario = Color(slotsHex: 0x3A3734)
    static let textoSobreOscuro = Color(slotsHex: 0xB9B4AE)
    static let teclaFondo = Color(slotsHex: 0xF1EDE8)
    static let linea = Color(slotsHex: 0xE6E3DF)
    static let vidrioTinte = Color(slotsHex: 0xF6F1EB, opacity: 0.58)
}

enum SlotsFont {
    static func tituloPantalla(_ compacto: Bool = false) -> Font {
        .custom("InterTight-Medium", size: compacto ? 44 : 64)
    }

    static let tituloHistorial = Font.custom("InterTight-Medium", size: 22)
    static let tituloCard = Font.custom("InterTight-Medium", size: 26)
    static let textoUI = Font.custom("InterTight-Regular", size: 15)
    static let etiqueta = Font.custom("InterTight-Medium", size: 12)
}

enum SlotsSpace {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let entreCards: CGFloat = 8
    static let paddingPanel: CGFloat = 32
}

enum SlotsRadius {
    static let card: CGFloat = 20
    static let ventana: CGFloat = 32
    static let chip: CGFloat = 8
    static let controlAlto: CGFloat = 48
}

/// Botón de acción principal en avisos del panel (el de la derecha).
struct SlotsPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SlotsFont.textoUI)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background {
                Capsule(style: .continuous)
                    .fill(SlotsColor.naranja.opacity(configuration.isPressed ? 0.8 : 1))
            }
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Capsule(style: .continuous))
    }
}

/// Botón secundario (Cancelar) junto a `SlotsPrimaryButtonStyle`.
struct SlotsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SlotsFont.textoUI)
            .foregroundStyle(SlotsColor.tinta)
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background {
                Capsule(style: .continuous)
                    .fill(SlotsColor.teclaFondo.opacity(configuration.isPressed ? 0.7 : 1))
            }
            .contentShape(Capsule(style: .continuous))
    }
}
