import Foundation
import TelemetryDeck

/// Telemetría anónima y opcional (TelemetryDeck). Solo contadores de uso: nunca el contenido copiado,
/// nombres de archivos, bibliotecas o slots, apps de origen ni datos personales.
/// Está apagada hasta que la persona la activa, y mientras `appID` esté vacío no hace nada.
enum Telemetry {
    /// App ID de TelemetryDeck (dashboard → Set Up App). Es público: viaja dentro de la app.
    static let appID = "C4398A7E-1329-4E1D-871C-BE0A83BA846F"

    enum Method: String {
        case panel, hotkey, notch
    }

    private static var started = false
    private static let firstSlotKey = "com.hotslot.telemetry.firstSlotReported"

    /// Se puede ofrecer el consentimiento solo si hay un App ID configurado.
    static var isConfigured: Bool { !appID.isEmpty }

    private static var hasConsent: Bool { AppSettings.load().analyticsEnabled }

    /// Arranca el SDK si hay consentimiento. Al revocarlo no se envía nada más (ver `signal`).
    static func startIfConsented() {
        guard isConfigured, hasConsent, !started else { return }
        TelemetryDeck.initialize(config: TelemetryDeck.Config(appID: appID))
        started = true
        signal("App.launched")
    }

    static func consentChanged() {
        startIfConsented()
    }

    static func signal(_ name: String, _ parameters: [String: String] = [:]) {
        guard started, hasConsent else { return }
        TelemetryDeck.signal(name, parameters: parameters)
    }

    // MARK: Eventos

    static func slotUsed(_ method: Method, content: ClipContent) {
        signal("Slot.used", ["method": method.rawValue, "kind": content.telemetryKind])
    }

    static func slotSaved(_ content: ClipContent) {
        signal("Slot.saved", ["kind": content.telemetryKind])
        guard !UserDefaults.standard.bool(forKey: firstSlotKey) else { return }
        UserDefaults.standard.set(true, forKey: firstSlotKey)
        signal("Slot.firstSaved")
    }

    static func notchOpened() { signal("Notch.opened") }
    static func libraryCreated() { signal("Library.created") }
    static func purchaseClicked() { signal("License.purchaseClicked") }
    static func licenseActivated() { signal("License.activated") }
}

private extension ClipContent {
    /// Tipo genérico, sin nombre ni contenido.
    var telemetryKind: String {
        switch self {
        case .text: return "text"
        case .image: return "image"
        case .file: return "file"
        }
    }
}
