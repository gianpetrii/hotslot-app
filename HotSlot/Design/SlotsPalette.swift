import SwiftUI

/// Colores de fondo permitidos para slots (marca Slots).
enum SlotsPalette {
    static let brandGradientAsset = "asset:degrade-naranja"

    static let slotBackgrounds: [(name: String, hex: UInt32)] = [
        ("Papel", 0xF2F2F0),
        ("Arena", 0xE7DED2),
        ("Naranja", 0xE2501D),
        ("Oscuro", 0x1C1C1C),
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
