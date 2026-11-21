import AppKit
import SwiftUI

/// Pide el permiso de Accesibilidad: diálogo del sistema primero, Ajustes como respaldo.
/// Lo usan Ajustes › Permisos y el paso de permiso del tutorial de primera vez.
enum AccessibilityGrantFlow {
    @MainActor
    static func request(appState: AppState, onResult: @escaping (Bool) -> Void) {
        appState.suppressSettingsAutoClose()
        DispatchQueue.main.async {
            if DevelopmentAppInstall.runsFromDerivedData {
                switch DevelopmentAppInstall.copyCurrentBuildToApplications() {
                case .success:
                    appState.showToast("Se abrió Slots desde Aplicaciones. Repetí Permisos → pedir permiso ahí.")
                    DevelopmentAppInstall.openApplicationsCopy()
                    return
                case .failure(let error):
                    appState.showToast("No se pudo copiar: \(error.localizedDescription)")
                }
            }

            AccessibilityPermission.requestAccessForPaste(focusWindow: appState.accessibilityPresentingWindow)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                let trusted = AccessibilityPermission.isTrusted
                onResult(trusted)
                guard !trusted else { return }
                if AccessibilityPermission.surfaceSystemPrompt(over: appState.accessibilityPresentingWindow) {
                    appState.showToast("En el aviso, tocá «Abrir Ajustes del Sistema» y activá Slots.")
                } else {
                    AccessibilityPermission.openSettings()
                    appState.showToast("Activá el interruptor junto a Slots en Accesibilidad.")
                }
            }
        }
    }
}

/// Botones de Ajustes › Permisos.
struct AccessibilityGrantSection: View {
    @Environment(AppState.self) private var appState
    @Binding var isTrusted: Bool

    var body: some View {
        Group {
            if isTrusted {
                SettingsPillButton(title: "Administrar en Ajustes del Sistema") {
                    appState.suppressSettingsAutoClose()
                    AccessibilityPermission.openSettings()
                }
            } else {
                SettingsPillButton(title: primaryButtonTitle, kind: .primary) {
                    AccessibilityGrantFlow.request(appState: appState) { isTrusted = $0 }
                }
                SettingsPillButton(title: "Abrir panel de Accesibilidad en Ajustes…") {
                    appState.suppressSettingsAutoClose()
                    AccessibilityPermission.openSettings()
                }
            }
        }
    }

    private var primaryButtonTitle: String {
        if DevelopmentAppInstall.runsFromDerivedData {
            return "Copiar a Aplicaciones y pedir permiso…"
        }
        return "Permitir Accesibilidad (diálogo del sistema)"
    }
}

enum AccessibilityPermissionCopy {
    static let promptFirst = """
    macOS muestra un aviso del sistema la primera vez. Si ya lo cerraste, se abre Accesibilidad en Ajustes para que actives \(BrandDisplay.name). La app no puede activarlo sola.
    """
}
