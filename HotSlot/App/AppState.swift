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
    let libraryWorkspace = LibraryWorkspaceStore()
    let clipboardService = ClipboardService()
    let pasteService = PasteService()
    let focusTracker = FocusTracker()
    let hotkeyManager = HotkeyManager()
    let notchNotice = NotchNoticeController()

    var toastMessage: String?
    var isPanelVisible = false
    var panelBodyRevealed = false
    var openSettings: (() -> Void)?
    var openOnboarding: (() -> Void)?
    /// Pestaña a abrir la próxima vez que se muestren Ajustes (p. ej. tras el tour).
    var pendingSettingsTab: SettingsTab?
    /// Sube cuando cambia un atajo grabado, para refrescar badges sin relanzar.
    var shortcutEpoch = 0

    /// Ventana delante de la cual mostrar el aviso de Accesibilidad (onboarding / ajustes).
    weak var accessibilityPresentingWindow: NSWindow?

    /// Sheet del panel: elegir slot cuando «Guardar portapapeles» y no hay vacíos.
    var isSaveClipboardSlotPickerPresented = false
    var isNewLibraryFormPresented = false

    /// Ajustes abiertos: el icono de menú bar no cierra el panel flotante al tocarlo.
    var isSettingsWindowVisible = false

    var settings: AppSettings {
        get { AppSettings.load() }
        set { newValue.save() }
    }

    func bootstrap(panelController: PanelController) {
        Entitlements.recordFirstLaunchIfNeeded()
        libraryWorkspace.importLegacySlotsIfNeeded(from: slotStore)
        libraryWorkspace.applyActiveLibrary(to: slotStore)
        slotStore.onPersist = { [weak self] in
            guard let self else { return }
            self.libraryWorkspace.syncFromLegacySlotStore(self.slotStore)
        }
        clipboardService.configure(historyStore: historyStore)
        pasteService.configure(clipboardService: clipboardService, focusTracker: focusTracker)

        notchNotice.configure {
            AccessibilityPermission.openSettings()
        }

        pasteService.onShowToast = { [weak self] message in
            if let message { self?.showToast(message) }
        }

        pasteService.onPasteSucceeded = { [weak self] slotIndex in
            guard let self else { return }
            let title = slotIndex.flatMap { self.slotDisplayTitle(at: $0) }
            self.presentNotch(.pasted(slotIndex: slotIndex, title: title))
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
            guard self.slotStore.content(at: index) != nil else {
                FeedbackSound.play(.pasteFailed)
                self.presentNotch(.emptySlot(index: index))
                return
            }
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
                    self.presentNotch(.saved(slotIndex: index, title: self.slotDisplayTitle(at: index)))
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
            self.pasteService.paste(content: content, targetApp: target, slotIndex: nil)
            self.focusTracker.clearPasteDestination()
        }
    }

    func pasteSlot(index: Int, panelController: PanelController) {
        guard ensureCanUseSlot(index) else { return }
        guard ensureAccessibilityForPaste() else { return }
        guard let content = slotStore.content(at: index) else {
            FeedbackSound.play(.pasteFailed)
            presentNotch(.emptySlot(index: index))
            return
        }
        let target = focusTracker.pasteDestination()
        panelController.hide(animated: true) {
            self.isPanelVisible = false
            self.pasteService.paste(content: content, targetApp: target, slotIndex: index)
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
            AccessibilityPermission.requestAccessForPaste(focusWindow: accessibilityPresentingWindow)
            presentNotch(.noAccessibility)
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

    /// Al abrir Licencia desde el panel: ir a General y scroll a la sección.
    var pendingScrollToLicense = false

    func openLicenseSettings() {
        pendingSettingsTab = .general
        pendingScrollToLicense = true
        openSettings?()
    }

    func saveToSlot(index: Int, content: ClipContent, announce: Bool = true, archivePreviousToHistory: Bool = false) {
        guard ensureCanUseSlot(index) else { return }
        if archivePreviousToHistory, let previous = slotStore.content(at: index) {
            historyStore.add(
                ClipItem(
                    content: previous,
                    createdAt: Date(),
                    sourceAppName: BrandDisplay.name,
                    sourceAppBundleID: Bundle.main.bundleIdentifier
                )
            )
        }
        slotStore.saveContent(index: index, content: content)
        if announce {
            FeedbackSound.play(.saved)
            presentNotch(.saved(slotIndex: index, title: slotDisplayTitle(at: index)))
        }
    }

    func firstEmptySlotIndex() -> Int? {
        (1 ... SlotStore.slotCount).first { slotStore.content(at: $0) == nil }
    }

    func saveClipboardFromPanel() {
        guard clipboardService.currentContent() != nil else {
            showToast("Nada en el portapapeles")
            FeedbackSound.play(.pasteFailed)
            return
        }
        if let empty = firstEmptySlotIndex() {
            guard let content = clipboardService.currentContent() else { return }
            saveToSlot(index: empty, content: content)
            UsageEventLog.shared.record("guardar_portapapeles", screen: "mac_panel")
            return
        }
        isSaveClipboardSlotPickerPresented = true
    }

    func saveClipboardToSlot(_ index: Int, replaceExisting: Bool) {
        guard ensureCanUseSlot(index) else { return }
        guard let content = clipboardService.currentContent() else {
            showToast("Nada en el portapapeles")
            return
        }
        let occupied = slotStore.content(at: index) != nil
        if occupied, !replaceExisting { return }
        saveToSlot(index: index, content: content, archivePreviousToHistory: occupied)
        isSaveClipboardSlotPickerPresented = false
        UsageEventLog.shared.record("guardar_portapapeles", screen: "mac_panel", detail: "slot_\(index)")
    }

    func presentNotch(_ kind: NotchNoticeKind) {
        notchNotice.present(kind)
    }

    func switchLibrary(to id: UUID) {
        libraryWorkspace.syncFromLegacySlotStore(slotStore)
        libraryWorkspace.setActiveLibrary(id: id)
        libraryWorkspace.applyActiveLibrary(to: slotStore)
        UsageEventLog.shared.record("biblioteca_cambiar", detail: libraryWorkspace.activeLibrary?.name)
    }

    func createLibrary(named name: String) {
        libraryWorkspace.syncFromLegacySlotStore(slotStore)
        libraryWorkspace.createLibrary(named: name)
        libraryWorkspace.applyActiveLibrary(to: slotStore)
        UsageEventLog.shared.record("biblioteca_crear", detail: name)
    }

    func replaceSlotFromClipboard(index: Int) {
        guard ensureCanUseSlot(index) else { return }
        guard let content = clipboardService.currentContent() else {
            showToast("Nada en el portapapeles")
            return
        }
        saveToSlot(index: index, content: content)
    }

    func moveSlotToLibrary(slotIndex: Int, libraryId: UUID) {
        guard ensureCanUseSlot(slotIndex) else { return }
        libraryWorkspace.syncFromLegacySlotStore(slotStore)
        guard libraryWorkspace.moveSlotContent(order: slotIndex, toLibraryId: libraryId) else {
            showToast("No hay slot vacío en esa biblioteca")
            return
        }
        libraryWorkspace.applyActiveLibrary(to: slotStore)
        UsageEventLog.shared.record("slot_mover_biblioteca", detail: "\(slotIndex)")
    }

    private func slotDisplayTitle(at index: Int) -> String? {
        let label = slotStore.slot(at: index)?.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let label, !label.isEmpty else { return nil }
        return label
    }
}
