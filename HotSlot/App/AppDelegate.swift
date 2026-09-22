import AppKit
import KeyboardShortcuts
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var panelController: PanelController?
    var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Evitar inicializar UI cuando XCTest inyecta el proceso
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }

        let state = AppState()
        let panel = PanelController(appState: state)
        let statusBar = StatusBarController(appState: state, panelController: panel)

        self.appState = state
        self.panelController = panel
        self.statusBarController = statusBar

        migrateHotkeysIfNeeded()
        state.bootstrap(panelController: panel)
        applyLaunchAtLoginSetting()
    }

    /// Una sola vez: aplica atajos nuevos (⌘⌃) para evitar conflicto con otras apps.
    private func migrateHotkeysIfNeeded() {
        let key = "hotslot.hotkeys.migrated.v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        KeyboardShortcuts.Name.resetAllToDefaults()
        UserDefaults.standard.set(true, forKey: key)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func applyLaunchAtLoginSetting() {
        let enabled = AppSettings.load().launchAtLogin
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // El usuario puede no tener permisos; ignorar silenciosamente en MVP
        }
    }
}
