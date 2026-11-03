import SwiftUI

/// Colores de fondo permitidos para slots (marca Slots).
enum SlotsPalette {
    static let brandGradientAsset = "asset:degrade-naranja"

    static let slotBackgrounds: [(name: String, hex: UInt32)] = [
        ("Handoff (blanco)", 0xFFFFFF),
        ("Papel", 0xF2F2F0),
        ("Arena", 0xE7DED2),
        ("Degradé naranja (marca)", 0xE2501D), // sentinel → asset in UI
        ("Oscuro", 0x1C1C1C),
    ]

    static func isBrandGradient(_ hexString: String?) -> Bool {
        hexString == brandGradientAsset
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
