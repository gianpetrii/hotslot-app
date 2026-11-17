import SwiftUI

/// Colores de fondo permitidos para slots (marca Slots).
enum SlotsPalette {
    static let brandGradientAsset = "asset:degrade-naranja"

    static let slotBackgrounds: [(name: String, hex: UInt32)] = [
        ("Tinta", 0x111111),
        ("Naranja", 0xE2501D),
        ("Arena", 0xE7DED2),
    ]

    static func isBrandGradient(_ hexString: String?) -> Bool {
        hexString == brandGradientAsset
    }

    /// Fondos sobre los que el texto tiene que ir claro (degradé, oscuro, hex oscuro).
    static func prefersLightContent(hexString: String?) -> Bool {
        if isBrandGradient(hexString) { return true }
        return isDarkHex(hexString)
    }

    /// Luminancia relativa sRGB; umbral 0.45 ≈ arena sigue texto oscuro, #1C1C1C texto claro.
    static func isDarkHex(_ hexString: String?) -> Bool {
        guard let hexString, !isBrandGradient(hexString) else { return false }
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return false }
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let r = linear(Double((value >> 16) & 0xFF) / 255)
        let g = linear(Double((value >> 8) & 0xFF) / 255)
        let b = linear(Double(value & 0xFF) / 255)
        return (0.2126 * r + 0.7152 * g + 0.0722 * b) < 0.45
    }

    /// `nil` y el blanco viejo (`#FFFFFF`) son el predeterminado. El degradé se conserva.
    static func storedBackgroundHex(_ hexString: String?) -> String? {
        guard let hexString else { return nil }
        let trimmed = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if isBrandGradient(trimmed) { return brandGradientAsset }
        var hex = trimmed
        if hex.hasPrefix("#") { hex.removeFirst() }
        if hex.count == 3, hex.allSatisfy(\.isHexDigit) {
            hex = hex.map { String($0) + String($0) }.joined()
        }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return trimmed }
        if value == 0xFFFFFF { return nil }
        return normalizedHex(value)
    }

    static func color(hexString: String?) -> Color? {
        guard let hexString, !hexString.isEmpty else { return nil }
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard let value = UInt32(hex, radix: 16) else { return nil }
        return Color(slotsHex: value)
    }

    static func normalizedHex(_ hex: UInt32) -> String {
        String(format: "#%06X", hex)
    }
}
