import AppKit
import Foundation

enum SettingsTab: Int {
    case hotkeys = 0
    case slots = 1
    case general = 2
    case permissions = 3
}

/// Estado global de la aplicación.
@MainActor
@Observable
final class AppState {
    let historyStore = HistoryStore()
    let slotStore = SlotStore()
    let clipboardService = ClipboardService()
    let pasteService = PasteService()
    let focusTracker = FocusTracker()
    let hotkeyManager = HotkeyManager()

    var toastMessage: String?
    var isPanelVisible = false
    var panelBodyRevealed = false
    var openSettings: (() -> Void)?
    var openOnboarding: (() -> Void)?
    /// Pestaña a abrir la próxima vez que se muestren Ajustes (p. ej. tras el tour).
    var pendingSettingsTab: SettingsTab?
    /// Sube cuando cambia un atajo grabado, para refrescar badges sin relanzar.
    var shortcutEpoch = 0

    var settings: AppSettings {
        get { AppSettings.load() }
        set { newValue.save() }
    }

    func bootstrap(panelController: PanelController) {
        Entitlements.recordFirstLaunchIfNeeded()
        clipboardService.configure(historyStore: historyStore)
        pasteService.configure(clipboardService: clipboardService, focusTracker: focusTracker)

        pasteService.onShowToast = { [weak self] message in
            if let message { self?.showToast(message) }
        }

        hotkeyManager.onTogglePanel = { [weak self, weak panelController] in
            guard let self, let panelController else { return }
            if panelController.isVisible {
                panelController.hide()
                self.isPanelVisible = false
            } else {
                self.focusTracker.captureForUpcomingPaste()
                panelController.show()
                self.isPanelVisible = true
            }
        }

        hotkeyManager.onPasteSlot = { [weak self] index in
            guard let self else { return }
            guard self.ensureCanUseSlot(index) else { return }
            guard self.ensureAccessibilityForPaste() else { return }
            self.focusTracker.capture()
            self.pasteService.pasteFromSlot(
                index: index,
                slotStore: self.slotStore,
                focusTracker: self.focusTracker
            )
        }

        hotkeyManager.onCopyToSlot = { [weak self] index in
            Task { @MainActor in
                guard let self else { return }
                guard self.ensureCanUseSlot(index) else { return }
                self.focusTracker.capture()
                if let content = await self.clipboardService.captureSelection() {
                    self.slotStore.saveContent(index: index, content: content)
                    FeedbackSound.play(.saved)
                    self.showToast("Guardado en slot \(index)")
                } else {
                    FeedbackSound.play(.pasteFailed)
                    self.showToast("Nada seleccionado para guardar")
                }
            }
        }

        hotkeyManager.registerAll()
        observeShortcutChanges()
        clipboardService.start()
        focusTracker.start()
    }

    func noteShortcutsChanged() {
        shortcutEpoch += 1
    }

    private func observeShortcutChanges() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hotkeyManager.reloadFromStorage()
                self?.noteShortcutsChanged()
            }
        }
    }

    func pasteItem(_ item: ClipItem, panelController: PanelController) {
        guard ensureCanUseHistory() else { return }
        guard ensureAccessibilityForPaste() else { return }
        let target = focusTracker.pasteDestination()
        let content = item.content
        panelController.hide(animated: true) {
            self.isPanelVisible = false
            self.pasteService.paste(content: content, targetApp: target)
            self.focusTracker.clearPasteDestination()
        }
    }

    func pasteSlot(index: Int, panelController: PanelController) {
        guard ensureCanUseSlot(index) else { return }
        guard ensureAccessibilityForPaste() else { return }
        guard let content = slotStore.content(at: index) else {
            FeedbackSound.play(.pasteFailed)
            showToast("El slot \(index) está vacío")
            return
        }
        let target = focusTracker.pasteDestination()
        panelController.hide(animated: true) {
            self.isPanelVisible = false
            self.pasteService.paste(content: content, targetApp: target)
            self.focusTracker.clearPasteDestination()
        }
    }

    func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.toastMessage == message {
                self?.toastMessage = nil
            }
        }
    }

    @discardableResult
    func ensureAccessibilityForPaste() -> Bool {
        guard AccessibilityPermission.isTrusted else {
            AccessibilityPermission.requestAccessForPaste()
            showToast("Permití el control en el diálogo del sistema (Accesibilidad)")
            FeedbackSound.play(.pasteFailed)
            return false
        }
        return true
    }

    @discardableResult
    func ensureCanUseSlot(_ index: Int) -> Bool {
        guard Entitlements.canUseSlot(index: index) else {
            promptUpgrade(feature: "slots 2–5")
            return false
        }
        return true
    }

    @discardableResult
    func ensureCanUseHistory() -> Bool {
        guard Entitlements.canUseHistoryAndExtraSlots else {
            promptUpgrade(feature: "historial y pegado desde el panel")
            return false
        }
        return true
    }

    func promptUpgrade(feature: String) {
        FeedbackSound.play(.pasteFailed)
        showToast("Prueba terminada — \(feature). Comprá Slots (USD 10) en Ajustes → Licencia")
    }

    func openPurchasePage() {
        NSWorkspace.shared.open(Entitlements.purchaseURL)
    }

    func saveToSlot(index: Int, content: ClipContent, announce: Bool = true) {
        guard ensureCanUseSlot(index) else { return }
        slotStore.saveContent(index: index, content: content)
        if announce {
            FeedbackSound.play(.saved)
            showToast("Guardado en slot \(index)")
        }
    }
}
