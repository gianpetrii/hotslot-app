import AppKit
import KeyboardShortcuts
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var panelController: PanelController?
    var appState: AppState?
    let settingsWindowController = SettingsWindowController()

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
        state.openSettings = { [weak self] in
            guard let self, let state = self.appState else { return }
            self.settingsWindowController.show(appState: state)
        }
        state.bootstrap(panelController: panel)
        applyLaunchAtLoginSetting()
    }

    /// Una sola vez: restaura atajos por defecto (⌘⇧V, ⌘⇧1–5, ⌘⌥1–5).
    private func migrateHotkeysIfNeeded() {
        let key = "hotslot.hotkeys.migrated.v3"
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
