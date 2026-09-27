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
            let reopenPanel = { [weak self] in
                guard let self else { return }
                self.appState?.focusTracker.capture()
                self.panelController?.show()
                NSApp.setActivationPolicy(.accessory)
            }
            if self.panelController?.isVisible == true {
                self.panelController?.hide(animated: true) {
                    self.settingsWindowController.show(appState: state, onDismiss: reopenPanel)
                }
            } else {
                self.settingsWindowController.show(appState: state, onDismiss: reopenPanel)
            }
        }
        state.bootstrap(panelController: panel)
        applyLaunchAtLoginSetting()
    }

    /// v3: primera instalación a defaults de entonces.
    /// v4: pegar 1–5 → A S D Q W; guardar 1–5 de fábrica → ⌘⌃ letras.
    /// v5: guardar ⌘⌥ letras (el default corto de v4) → ⌘⌃ letras.
    private func migrateHotkeysIfNeeded() {
        let v3 = "hotslot.hotkeys.migrated.v3"
        if !UserDefaults.standard.bool(forKey: v3) {
            KeyboardShortcuts.Name.resetAllToDefaults()
            UserDefaults.standard.set(true, forKey: v3)
        }

        let v4 = "hotslot.hotkeys.migrated.v4"
        if !UserDefaults.standard.bool(forKey: v4) {
            let pastePairs = zip(
                KeyboardShortcuts.Name.pasteSlotNames,
                KeyboardShortcuts.Name.legacyNumericPasteDefaults
            )
            for (name, oldDefault) in pastePairs {
                migrateSlotShortcut(name, ifStill: [oldDefault])
            }

            let copyPairs = zip(
                KeyboardShortcuts.Name.copyToSlotNames,
                KeyboardShortcuts.Name.legacyNumericCopyDefaults
            )
            for (name, oldDefault) in copyPairs {
                migrateSlotShortcut(name, ifStill: [oldDefault])
            }
            UserDefaults.standard.set(true, forKey: v4)
        }

        let v5 = "hotslot.hotkeys.migrated.v5"
        guard !UserDefaults.standard.bool(forKey: v5) else { return }
        let copyPairs = zip(
            KeyboardShortcuts.Name.copyToSlotNames,
            zip(
                KeyboardShortcuts.Name.legacyNumericCopyDefaults,
                KeyboardShortcuts.Name.legacyOptionLetterCopyDefaults
            )
        )
        for (name, old) in copyPairs {
            migrateSlotShortcut(name, ifStill: [old.0, old.1])
        }
        UserDefaults.standard.set(true, forKey: v5)
    }

    private func migrateSlotShortcut(
        _ name: KeyboardShortcuts.Name,
        ifStill oldDefaults: [KeyboardShortcuts.Shortcut]
    ) {
        let current = KeyboardShortcuts.getShortcut(for: name)
        if current == nil || oldDefaults.contains(where: { $0 == current }) {
            KeyboardShortcuts.reset(name)
        }
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
