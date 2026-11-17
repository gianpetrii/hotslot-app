import SwiftUI

extension SlotsFont {
    static func medium(_ size: CGFloat) -> Font { .custom("InterTight-Medium", fixedSize: size) }
    static func regular(_ size: CGFloat) -> Font { .custom("InterTight-Regular", fixedSize: size) }
}

/// Texto con la tipografía, el tracking y el interlineado del handoff (que vienen en `em`).
struct SlotsTextStyle: ViewModifier {
    var size: CGFloat
    var medium = true
    /// Tracking en `em` (p. ej. -0.035).
    var tracking: CGFloat = 0
    /// Interlineado como múltiplo del tamaño (p. ej. 0.95).
    var lineHeight: CGFloat = 1.2

    /// Alto de línea natural de Inter Tight, en `em`.
    private static let naturalLineHeight: CGFloat = 1.21

    func body(content: Content) -> some View {
        content
            .font(medium ? SlotsFont.medium(size) : SlotsFont.regular(size))
            .tracking(tracking * size)
            // `lineSpacing` no acepta valores negativos: el interlineado apretado se logra con el múltiplo.
            .environment(\._lineHeightMultiple, lineHeight / Self.naturalLineHeight)
    }
}

extension View {
    func slotsText(_ size: CGFloat, medium: Bool = true, tracking: CGFloat = 0, lineHeight: CGFloat = 1.2) -> some View {
        modifier(SlotsTextStyle(size: size, medium: medium, tracking: tracking, lineHeight: lineHeight))
    }
}
