import Foundation

/// Detecta un color hex (`#E2501D` o `E2501D`) en un texto copiado.
enum HexColor {
    /// `#RRGGBB` en mayúsculas, o `nil` si el texto no es un color de seis dígitos.
    static func normalized(_ string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: #"^#?[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil else { return nil }
        return trimmed.hasPrefix("#") ? trimmed.uppercased() : "#\(trimmed.uppercased())"
    }
}
