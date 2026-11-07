import AppKit
import Foundation

enum SettingsTab: Int {
    case hotkeys = 0
    case general = 2
    case permissions = 3
}

struct LibraryDragSession: Equatable {
    let libraryId: UUID
    let originIndex: Int
    let startFrame: CGRect
    var translation: CGSize
    var location: CGPoint
    var insertIndex: Int
    /// Soltada: la copia flotante viaja a su lugar final antes de cerrar la sesión.
    var isSettling = false
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
    /// Versión nueva encontrada en segundo plano. Sparkle no la muestra sola en apps de barra de menú.
    var availableUpdateVersion: String?
    /// Sube cuando cambia un atajo grabado, para refrescar badges sin relanzar.
    var shortcutEpoch = 0
    /// Incrementa al cambiar biblioteca activa (animación del cuerpo del panel).
    var librarySwitchRevision = 0
    /// Hay un título de biblioteca o slot en edición. El clic fuera o Esc lo cierran.
    var isInlineEditing = false
    /// Sube para pedir a los editores inline que cierren (`inlineEditShouldSave`).
    var inlineEditSession = 0
    var inlineEditShouldSave = true
    /// Ventana delante de la cual mostrar el aviso de Accesibilidad (onboarding / ajustes).
    weak var accessibilityPresentingWindow: NSWindow?

    /// Sheet del panel: elegir slot cuando «Guardar portapapeles» y no hay vacíos.
    var isSaveClipboardSlotPickerPresented = false
    var isNewLibraryFormPresented = false
    var deleteLibraryConfirmation: Library?
    var renameLibraryTarget: Library?

    /// Arrastre de pill de biblioteca (reorden / tacho flotante). Coordenadas en `PanelView.coordinateSpaceName`.
    var libraryDrag: LibraryDragSession?
    var libraryTrashFrame: CGRect = .zero

    var libraryDragActiveId: UUID? { libraryDrag?.libraryId }

    var floatingLibraryTrashTargeted: Bool {
        guard let libraryDrag, libraryTrashFrame != .zero else { return false }
        return libraryTrashFrame.insetBy(dx: -24, dy: -20).contains(libraryDrag.location)
    }

    /// Ajustes abiertos: el icono de menú bar no cierra el panel flotante al tocarlo.
    var isSettingsWindowVisible = false

    var settings: AppSettings {
        get { AppSettings.load() }
        set { newValue.save() }
    }

    func bootstrap(panelController: PanelController) {
        Entitlements.recordFirstLaunchIfNeeded()
        slotStore.onPersist = { [weak self] in
            guard let self else { return }
            self.libraryWorkspace.syncFromLegacySlotStore(self.slotStore)
        }
        libraryWorkspace.importLegacySlotsIfNeeded(from: slotStore)
        libraryWorkspace.applyActiveLibrary(to: slotStore, preservingMissingBackgrounds: true)
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

        pasteService.onCopied = { [weak self] slotIndex in
            guard let self else { return }
            let title = slotIndex.flatMap { self.slotDisplayTitle(at: $0) }
            self.presentNotch(.copied(slotIndex: slotIndex, title: title))
            self.showToast("Copiado — ⌘V para pegar")
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
        activateContent(item.content, slotIndex: nil, panelController: panelController)
    }

    func pasteSlot(index: Int, panelController: PanelController) {
        guard ensureCanUseSlot(index) else { return }
        guard let content = slotStore.content(at: index) else {
            FeedbackSound.play(.pasteFailed)
            presentNotch(.emptySlot(index: index))
            return
        }
        activateContent(content, slotIndex: index, panelController: panelController)
    }

    /// Clic en slot o historial: copia o pega, según Ajustes. Los atajos de teclado siguen pegando.
    /// El cierre espera un instante para que el relleno del clic se pinte; la duración del cierre no cambia.
    private func activateContent(_ content: ClipContent, slotIndex: Int?, panelController: PanelController) {
        if content.isMissingFile {
            FeedbackSound.play(.pasteFailed)
            presentNotch(.plain("El archivo ya no está en su lugar"))
            return
        }
        let close = {
            switch self.settings.clickItemAction {
            case .copyToClipboard:
                panelController.hide(animated: true) {
                    self.isPanelVisible = false
                    self.pasteService.copyToClipboard(content: content, slotIndex: slotIndex)
                    self.focusTracker.clearPasteDestination()
                }
            case .pasteAtFocus:
                guard self.ensureAccessibilityForPaste() else { return }
                let target = self.focusTracker.pasteDestination()
                panelController.hide(animated: true) {
                    self.isPanelVisible = false
                    self.pasteService.paste(content: content, targetApp: target, slotIndex: slotIndex)
                    self.focusTracker.clearPasteDestination()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            close()
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                AccessibilityPermission.surfaceSystemPrompt(over: self?.accessibilityPresentingWindow)
            }
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
        librarySwitchRevision += 1
        UsageEventLog.shared.record("biblioteca_cambiar", detail: libraryWorkspace.activeLibrary?.name)
    }

    func createLibrary(named name: String) {
        libraryWorkspace.syncFromLegacySlotStore(slotStore)
        libraryWorkspace.createLibrary(named: name)
        libraryWorkspace.applyActiveLibrary(to: slotStore)
        UsageEventLog.shared.record("biblioteca_crear", detail: name)
    }

    @discardableResult
    func deleteLibrary(id: UUID) -> Bool {
        libraryWorkspace.syncFromLegacySlotStore(slotStore)
        guard libraryWorkspace.deleteLibrary(id: id) else { return false }
        libraryWorkspace.applyActiveLibrary(to: slotStore)
        librarySwitchRevision += 1
        UsageEventLog.shared.record("biblioteca_eliminar")
        return true
    }

    func moveLibrary(id: UUID, toIndex index: Int) {
        libraryWorkspace.syncFromLegacySlotStore(slotStore)
        libraryWorkspace.moveLibrary(id: id, toIndex: index)
        UsageEventLog.shared.record("biblioteca_reordenar")
    }

    /// Eliminar desde tacho o menú: confirma salvo que el usuario haya elegido no volver a preguntar.
    func requestDeleteLibrary(_ library: Library) {
        guard libraryWorkspace.workspace.libraries.count > 1 else {
            showToast("Tiene que quedar al menos una biblioteca")
            return
        }
        if settings.confirmLibraryDelete {
            deleteLibraryConfirmation = library
        } else {
            deleteLibrary(id: library.id)
        }
    }

    func setConfirmLibraryDelete(_ confirm: Bool) {
        var current = settings
        current.confirmLibraryDelete = confirm
        settings = current
    }

    func renameLibrary(id: UUID, name: String) {
        libraryWorkspace.syncFromLegacySlotStore(slotStore)
        libraryWorkspace.renameLibrary(id: id, name: name)
        UsageEventLog.shared.record("biblioteca_renombrar", detail: name)
    }

    func beginInlineEdit() {
        if isInlineEditing {
            endInlineEdit(save: true)
        }
        isInlineEditing = true
    }

    /// Clic fuera o Enter: `save == true`. Esc: `save == false` (vuelve al texto anterior).
    func endInlineEdit(save: Bool) {
        guard isInlineEditing else { return }
        inlineEditShouldSave = save
        inlineEditSession += 1
        isInlineEditing = false
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
