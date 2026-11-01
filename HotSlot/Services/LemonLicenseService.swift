import Foundation

/// Activación de licencias emitidas por Lemon Squeezy (UUID + License API pública).
enum LemonLicenseService {
    /// Variant del checkout publicado (último segmento del enlace de compra).
    static let expectedVariantID = "a2e83610-199d-4d93-91f4-32d63f57d05d"

    private static let activateURL = URL(string: "https://api.lemonsqueezy.com/v1/licenses/activate")!

    struct ActivateResponse: Decodable {
        let activated: Bool
        let error: String?
        let meta: Meta?

        struct Meta: Decodable {
            let variant_id: Int?
            let product_name: String?
        }
    }

    static func activate(licenseKey: String) async -> (success: Bool, message: String?) {
        let key = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard LicenseKeyFormat.isLemonKey(key) else {
            return (false, "Formato de clave no reconocido")
        }

        let instanceName = instanceLabel()
        var request = URLRequest(url: activateURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let body = "license_key=\(key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key)"
            + "&instance_name=\(instanceName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? instanceName)"
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (false, "Sin respuesta del servidor")
            }
            guard (200 ... 299).contains(http.statusCode) else {
                return (false, "No se pudo activar (código \(http.statusCode))")
            }

            let decoded = try JSONDecoder().decode(ActivateResponse.self, from: data)
            if let error = decoded.error, !error.isEmpty {
                return (false, error)
            }
            guard decoded.activated else {
                return (false, "Clave rechazada o sin activaciones disponibles")
            }

            return (true, nil)
        } catch {
            return (false, "Revisá tu conexión e intentá de nuevo")
        }
    }

    private static func instanceLabel() -> String {
        let host = Host.current().localizedName ?? "Mac"
        return "Slots-\(host)-\(Bundle.main.bundleIdentifier ?? "app")"
    }
}
