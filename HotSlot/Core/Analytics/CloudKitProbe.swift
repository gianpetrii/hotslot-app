import AppKit
import CloudKit
import Security

/// Prueba técnica del sync: ¿la app firmada tiene permiso de iCloud y llega a la base privada del usuario?
/// Solo se ve en el menú oculto (⌥ + clic derecho). No guarda ni sube nada.
enum CloudKitProbe {
    static let containerID = "iCloud.com.hotslot.app"

    @MainActor
    static func run() {
        Task { @MainActor in
            var lines = ["Contenedor: \(containerID)"]

            if hasEntitlement("com.apple.developer.icloud-services") {
                lines.append("Permiso de iCloud en la firma: sí")
                do {
                    let container = CKContainer(identifier: containerID)
                    let status = try await container.accountStatus()
                    lines.append("Cuenta de iCloud: \(describe(status))")
                    if status == .available {
                        let zones = try await container.privateCloudDatabase.allRecordZones()
                        lines.append("Base privada accesible (\(zones.count) zonas)")
                    }
                } catch {
                    lines.append("Error: \(error.localizedDescription)")
                }
            } else {
                lines.append("Permiso de iCloud en la firma: NO (la app no se firmó con iCloud)")
            }

            lines.append("Aviso de cambios (push): \(hasEntitlement("com.apple.developer.aps-environment") ? "sí" : "NO")")

            let alert = NSAlert()
            alert.messageText = "Prueba de iCloud"
            alert.informativeText = lines.joined(separator: "\n")
            alert.addButton(withTitle: "Cerrar")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    private static func hasEntitlement(_ key: String) -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        return SecTaskCopyValueForEntitlement(task, key as CFString, nil) != nil
    }

    private static func describe(_ status: CKAccountStatus) -> String {
        switch status {
        case .available: return "disponible"
        case .noAccount: return "sin sesión de iCloud"
        case .restricted: return "restringida"
        case .couldNotDetermine: return "no se pudo determinar"
        case .temporarilyUnavailable: return "no disponible por ahora"
        @unknown default: return "desconocida"
        }
    }
}
