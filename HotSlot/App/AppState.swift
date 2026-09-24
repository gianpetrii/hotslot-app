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
    var openSettings: (() -> Void)?

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
            guard let self else { return }
            if let content = self.clipboardService.currentContent() {
                self.slotStore.saveContent(index: index, content: content)
                self.showToast("Guardado en slot \(index)")
            }
        }

        hotkeyManager.registerAll()
        clipboardService.start()
    }

    func pasteItem(_ item: ClipItem, panelController: PanelController) {
        let target = focusTracker.targetApp
        let content = item.content
        panelController.hide(animated: true) {
            self.isPanelVisible = false
            self.pasteService.paste(content: content, targetApp: target)
        }
    }

    func pasteSlot(index: Int, panelController: PanelController) {
        guard let content = slotStore.content(at: index) else {
            showToast("El slot \(index) está vacío")
            return
        }
        let target = focusTracker.targetApp
        panelController.hide(animated: true) {
            self.isPanelVisible = false
            self.pasteService.paste(content: content, targetApp: target)
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
