import AppKit
import Carbon
import KeyboardShortcuts
import ServiceManagement
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var panelController: PanelController?
    var appState: AppState?
    let settingsWindowController = SettingsWindowController()
    let onboardingWindowController = OnboardingWindowController()
    private var updaterController: SPUStandardUpdaterController?
    private var shouldReopenPanelAfterUtility = false
    private var shouldPresentPanelAfterLaunch = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        terminateOtherInstances()
        if let event = NSAppleEventManager.shared().currentAppleEvent,
           event.eventClass == AEEventClass(kCoreEventClass),
           event.eventID == AEEventID(kAEOpenApplication) {
            shouldPresentPanelAfterLaunch = true
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Evitar inicializar UI cuando XCTest inyecta el proceso
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }

        migrateHotkeysIfNeeded()
        AppSupportDirectory.migrateUnsandboxedIfNeeded()
        let state = AppState()
        let panel = PanelController(appState: state)
        let statusBar = StatusBarController(
            appState: state,
            panelController: panel,
            onCheckForUpdates: { [weak self] in
                self?.checkForUpdates()
            }
        )

        self.appState = state
        self.panelController = panel
        self.statusBarController = statusBar

        state.openSettings = { [weak self] in
            guard let self, let state = self.appState else { return }
            self.presentUtilityWindow {
                self.settingsWindowController.show(appState: state, onDismiss: $0)
            }
        }
        state.openOnboarding = { [weak self] in
            guard let self, let state = self.appState else { return }
            self.presentUtilityWindow { reopen in
                self.onboardingWindowController.show(appState: state) { openPanel in
                    NSApp.setActivationPolicy(.accessory)
                    guard openPanel else { return }
                    reopen()
                }
            }
        }
        state.bootstrap(panelController: panel)
        applyLaunchAtLoginSetting()
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        if !AppSettings.load().hasCompletedOnboarding {
            DispatchQueue.main.async { [weak self] in
                self?.appState?.openOnboarding?()
            }
        } else if shouldPresentPanelAfterLaunch {
            DispatchQueue.main.async { [weak self] in
                self?.presentPanelFromUserLaunchIfAppropriate()
            }
        }
    }

    /// Doble clic en Aplicaciones o reabrir la app: mostrar el panel (no al iniciar sesión en segundo plano).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        presentPanelFromUserLaunchIfAppropriate()
        return true
    }

    @MainActor
    private func presentPanelFromUserLaunchIfAppropriate() {
        guard let panel = panelController, let state = appState else { return }
        guard AppSettings.load().hasCompletedOnboarding else { return }
        guard !panel.isVisible else { return }

        let isFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
        guard isFrontmost || shouldPresentPanelAfterLaunch else { return }

        shouldPresentPanelAfterLaunch = false
        state.focusTracker.captureForUpcomingPaste()
        panel.show()
        state.isPanelVisible = true
    }

    @MainActor
    func openSettingsFromAppMenu() {
        guard let state = appState else { return }
        presentUtilityWindow { [self] reopen in
            settingsWindowController.show(appState: state, onDismiss: reopen)
        }
    }

    @MainActor
    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    @MainActor
    private func presentUtilityWindow(show: @escaping (@escaping () -> Void) -> Void) {
        shouldReopenPanelAfterUtility = panelController?.isVisible == true

        let finishUtility = { [weak self] in
            guard let self else { return }
            NSApp.setActivationPolicy(.accessory)
            guard self.shouldReopenPanelAfterUtility else { return }
            self.appState?.focusTracker.capture()
            self.panelController?.show()
            self.appState?.isPanelVisible = true
        }

        if shouldReopenPanelAfterUtility {
            panelController?.hide(animated: true) {
                self.appState?.isPanelVisible = false
                show(finishUtility)
            }
        } else {
            show(finishUtility)
        }
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

    /// Solo una instancia (menú bar). Cada Run de Xcode mata la anterior; evita mezclar builds viejos y nuevos.
    private func terminateOtherInstances() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let myPID = ProcessInfo.processInfo.processIdentifier
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
            guard app.processIdentifier != myPID else { continue }
            app.terminate()
        }
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
