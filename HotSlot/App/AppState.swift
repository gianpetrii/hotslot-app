import AppKit
import Foundation

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
    /// Sube cuando cambia un atajo grabado, para refrescar badges sin relanzar.
    var shortcutEpoch = 0

    var settings: AppSettings {
        get { AppSettings.load() }
        set { newValue.save() }
    }

    func bootstrap(panelController: PanelController) {
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
                self.focusTracker.capture()
                panelController.show()
                self.isPanelVisible = true
            }
        }

        hotkeyManager.onPasteSlot = { [weak self] index in
            guard let self else { return }
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
                self?.noteShortcutsChanged()
            }
        }
    }

    func pasteItem(_ item: ClipItem, panelController: PanelController) {
        let target = focusTracker.targetApp
        let content = item.content
        panelController.hide(animated: true) {
            self.isPanelVisible = false
            self.pasteService.paste(
                content: content,
                targetApp: FocusTracker.pasteTarget(preferred: target)
            )
        }
    }

    func pasteSlot(index: Int, panelController: PanelController) {
        guard let content = slotStore.content(at: index) else {
            FeedbackSound.play(.pasteFailed)
            showToast("El slot \(index) está vacío")
            return
        }
        let target = focusTracker.targetApp
        panelController.hide(animated: true) {
            self.isPanelVisible = false
            self.pasteService.paste(
                content: content,
                targetApp: FocusTracker.pasteTarget(preferred: target)
            )
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
}
