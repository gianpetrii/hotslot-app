import AppKit

/// Automatización (Apple Events → System Events) para pegar y copiar selección.
enum AutomationPermission {
    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
