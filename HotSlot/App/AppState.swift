import AppKit
import Foundation
import KeyboardShortcuts

/// Pide a la grilla que muestre un slot. `token` hace que dos pedidos al mismo slot sean distintos.
struct SlotScrollTarget: Equatable {
    let index: Int
    let token = UUID()
}

enum SettingsTab: Int {
    case hotkeys = 0
    case general = 2
    case permissions = 3

    var title: String {
        switch self {
        case .general: "General"
        case .hotkeys: "Atajos"
        case .permissions: "Permisos"
        }
    }
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
    let slotStore: SlotStore
    let libraryWorkspace: LibraryWorkspaceStore
    let clipboardService = ClipboardService()
    let pasteService = PasteService()
    let focusTracker = FocusTracker()
    let hotkeyManager = HotkeyManager()
    let notchNotice = NotchNoticeController()

    init() {
        let workspace = LibraryWorkspaceStore()
        libraryWorkspace = workspace
        slotStore = SlotStore(workspace: workspace)
    }

    var toastMessage: String?
    var isPanelVisible = false
    var panelBodyRevealed = false
    var openSettings: (() -> Void)?
    var openOnboarding: (() -> Void)?
    /// Tutorial de primera vez (también desde Ajustes › Ayuda).
    var openTutorial: (() -> Void)?
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
    /// Ajustes se cierra al perder el foco; mientras dura un aviso del sistema o una página externa no.
    var settingsAutoCloseSuppressedUntil = Date.distantPast

    func suppressSettingsAutoClose(for seconds: TimeInterval = 20) {
        settingsAutoCloseSuppressedUntil = Date().addingTimeInterval(seconds)
    }

    /// Slot recién creado que espera nombre o contenido: ⌘V lo llena y Esc lo descarta.
    var pendingNewSlot: Int?
    /// La grilla hace scroll hasta este slot.
    var slotScrollTarget: SlotScrollTarget?
    var swapHighlight: SwapHighlight?
    /// Slot que se está arrastrando ahora (lo fija la card al empezar el arrastre).
    var slotDragSource: (index: Int, libraryId: UUID, grab: CGPoint, size: CGSize)?
    /// Sube cada vez que se abre la barra del notch: vuelve a la primera página de slots.
    var notchOpenCount = 0
    /// Pedido de cambio de página desde la rueda del mouse sobre la barra (+1 / -1).
    var notchPageRequest: Int?
    /// Se arrastra una biblioteca en el notch: la barra no se cierra aunque el cursor baje al tacho.
    var notchLibraryDragging = false
    /// Slot que acaba de recibir contenido: el panel y el notch lo destacan un momento.
    /// Slot recién copiado con un clic: la card muestra «Copiado», igual que en iOS. Se limpia al reabrir el panel.
    var copiedSlotIndex: Int?
    var slotArrival: SlotArrival?

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
        libraryWorkspace.migrateLegacySlotsIfNeeded()
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
            if let content = self.slotStore.content(at: index) {
                Telemetry.slotUsed(.hotkey, content: content)
            }
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
                    Telemetry.slotSaved(content)
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

    func pasteSlot(index: Int, panelController: PanelController, via method: Telemetry.Method = .panel) {
        guard ensureCanUseSlot(index) else { return }
        guard let content = slotStore.content(at: index) else {
            FeedbackSound.play(.pasteFailed)
            presentNotch(.emptySlot(index: index))
            return
        }
        Telemetry.slotUsed(method, content: content)
        activateContent(content, slotIndex: index, panelController: panelController)
    }

    /// Clic en slot o historial: copia o pega, según Ajustes. Los atajos de teclado siguen pegando.
    /// El cierre espera un instante para que el relleno del clic se pinte; la duración del cierre no cambia.
    private func activateContent(_ content: ClipContent, slotIndex: Int?, panelController: PanelController) {
        if content.isMissingFile {
            FeedbackSound.play(.pasteFailed)
            presentNotch(.plain(content.isRemoteOnlyFile
                ? "Este archivo está en otro dispositivo"
                : "El archivo ya no está en su lugar"))
            return
        }
        let close = {
            switch self.settings.clickItemAction {
            case .copyToClipboard:
                // Sonido y aviso en el instante del clic; el panel se cierra en paralelo.
                self.pasteService.copyToClipboard(content: content, slotIndex: slotIndex)
                self.focusTracker.clearPasteDestination()
                panelController.hide(animated: true) {
                    self.isPanelVisible = false
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
        switch settings.clickItemAction {
        case .copyToClipboard:
            close()
        case .pasteAtFocus:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                close()
            }
        }
    }

    /// Avisos de una línea. Salen en la barra del notch, igual que Guardado o Copiado;
    /// si ese aviso está apagado en Ajustes, caen al cartel del panel.
    func showToast(_ message: String) {
        if AppSettings.load().showNotchNotice {
            presentNotch(.plain(message))
            return
        }
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
        suppressSettingsAutoClose(for: 30)
        Telemetry.purchaseClicked()
        NSWorkspace.shared.open(Entitlements.purchaseURL)
    }

    /// Al abrir Licencia desde el panel: ir a General y scroll a la sección.
    var pendingScrollToLicense = false

    func openLicenseSettings() {
        pendingSettingsTab = .general
        pendingScrollToLicense = true
        openSettings?()
    }

    struct SlotArrival: Equatable {
        let index: Int
        let token = UUID()
    }

    private func markSlotArrival(_ index: Int) {
        let arrival = SlotArrival(index: index)
        slotArrival = arrival
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            if self?.slotArrival == arrival { self?.slotArrival = nil }
        }
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
        Telemetry.slotSaved(content)
        if announce {
            markSlotArrival(index)
            FeedbackSound.play(.saved)
            presentNotch(.saved(slotIndex: index, title: slotDisplayTitle(at: index)))
        }
    }

    func firstEmptySlotIndex() -> Int? {
        (1 ... SlotStore.slotCount).first { slotStore.content(at: $0) == nil }
    }

    /// «Guardar portapapeles»: usa el primer slot vacío; si están todos ocupados, crea uno al final.
    func saveClipboardFromPanel() {
        guard let content = clipboardService.currentContent() else {
            showToast("Nada en el portapapeles")
            FeedbackSound.play(.pasteFailed)
            return
        }
        if let empty = slotStore.allSlots.first(where: { $0.content == nil && $0.index != pendingNewSlot })?.index {
            saveToSlot(index: empty, content: content)
            slotScrollTarget = SlotScrollTarget(index: empty)
            UsageEventLog.shared.record("guardar_portapapeles", screen: "mac_panel", detail: "slot_\(empty)")
        } else if saveToNewSlot(content: content) != nil {
            UsageEventLog.shared.record("guardar_portapapeles", screen: "mac_panel")
        }
    }

    // MARK: - Slots nuevos

    /// Nuevo slot vacío al final, con el nombre en edición. Devuelve su posición.
    @discardableResult
    func createSlotAndEditName() -> Int? {
        guard ensureCanUseSlot(slotStore.totalSlotCount + 1) else { return nil }
        if let previous = pendingNewSlot, slotStore.content(at: previous) == nil,
           slotStore.slot(at: previous).map({ !SlotCardCopy.hasCustomLabel($0) }) == true {
            // Había uno nuevo sin usar: no se acumulan slots vacíos sin nombre.
            discardPendingNewSlot()
        }
        guard let order = slotStore.addSlot() else { return nil }
        pendingNewSlot = order
        slotScrollTarget = SlotScrollTarget(index: order)
        UsageEventLog.shared.record("slot_nuevo", screen: "mac_panel", detail: "\(order)")
        return order
    }

    /// Esc sobre un slot nuevo sin nombre ni contenido: vuelve a ser «Nuevo slot».
    func discardPendingNewSlot() {
        guard let order = pendingNewSlot else { return }
        pendingNewSlot = nil
        if slotStore.content(at: order) == nil {
            slotStore.removeSlot(index: order)
        }
    }

    /// Crea un slot al final con `content` y avisa «Guardado».
    @discardableResult
    func saveToNewSlot(content: ClipContent) -> Int? {
        guard ensureCanUseSlot(slotStore.totalSlotCount + 1) else { return nil }
        guard let order = slotStore.addSlot() else { return nil }
        saveToSlot(index: order, content: content)
        slotScrollTarget = SlotScrollTarget(index: order)
        return order
    }

    /// ⌘V con un slot nuevo a la vista: guarda el portapapeles ahí.
    func saveClipboardToPendingSlot() {
        guard let order = pendingNewSlot else { return }
        guard let content = clipboardService.currentContent() else {
            showToast("Nada en el portapapeles")
            FeedbackSound.play(.pasteFailed)
            return
        }
        pendingNewSlot = nil
        saveToSlot(index: order, content: content)
    }

    /// Dos slots que acaban de intercambiarse: la grilla los resalta un momento.
    struct SwapHighlight: Equatable {
        let indices: Set<Int>
        /// Posición donde cayó el slot arrastrado (su card ya "aterriza" ahí sin viajar).
        let landed: Int
        /// Dónde se soltó, respecto del centro de esa card: de ahí arranca el aterrizaje.
        var landOffset: CGSize = .zero
        var landScale: CGSize = CGSize(width: 1, height: 1)
        /// Falso en el primer cuadro (pose de partida), verdadero cuando arranca la animación.
        var running = false
        let token = UUID()
    }

    /// Intercambia dos slots (contenido, nombre y fondo); los demás quedan donde estaban.
    /// Un slot que pasa a ocupar una de las 5 primeras posiciones toma ese atajo.
    func reorderSlot(from source: Int, to destination: Int, dropOffset: CGSize = .zero, dropScale: CGSize = CGSize(width: 1, height: 1)) {
        guard source != destination else { return }
        let sourceTitle = slotDisplayTitle(at: source)
        let destinationTitle = slotDisplayTitle(at: destination)
        let limit = SlotStore.slotCount
        guard slotStore.swapSlots(source, destination) else { return }
        UsageEventLog.shared.record("slot_reordenar", detail: "\(source)<->\(destination)")
        let marker = SwapHighlight(indices: [source, destination], landed: destination, landOffset: dropOffset, landScale: dropScale)
        swapHighlight = marker
        // Un instante después, la pose de partida pasa a la final y se anima.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            guard self?.swapHighlight?.token == marker.token else { return }
            self?.swapHighlight?.running = true
        }
        FeedbackSound.play(.saved)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            if self?.swapHighlight?.token == marker.token { self?.swapHighlight = nil }
        }
        // El que llegó a una posición con atajo (desde una sin atajo) lo avisa.
        func shortcut(_ position: Int) -> String {
            let name = KeyboardShortcuts.Name.pasteSlotNames[position - 1]
            return KeyboardShortcuts.Shortcut(name: name)?.description ?? ""
        }
        if destination <= limit, source > limit {
            presentNotch(.plain("\(sourceTitle ?? "Slot \(destination)") · ahora \(shortcut(destination))"))
        } else if source <= limit, destination > limit {
            presentNotch(.plain("\(destinationTitle ?? "Slot \(source)") · ahora \(shortcut(source))"))
        } else {
            presentNotch(.plain("\(sourceTitle ?? "Slot \(source)") ⇄ \(destinationTitle ?? "Slot \(destination)")"))
        }
    }

    /// Elimina un slot sin atajo de fábrica (6 en adelante). Lo que tenía pasa al historial y los siguientes suben un lugar.
    func deleteSlot(index: Int) {
        guard index > SlotStore.slotCount, slotStore.slot(at: index) != nil else { return }
        if let previous = slotStore.content(at: index) {
            historyStore.add(
                ClipItem(
                    content: previous,
                    createdAt: Date(),
                    sourceAppName: BrandDisplay.name,
                    sourceAppBundleID: Bundle.main.bundleIdentifier
                )
            )
        }
        guard slotStore.removeSlot(index: index) else { return }
        UsageEventLog.shared.record("slot_eliminar", detail: "\(index)")
        showToast("Slot eliminado")
    }

    /// Manda un slot al final de la biblioteca; los demás se corren para tapar el hueco.
    func moveSlotToEnd(from source: Int) {
        let last = slotStore.totalSlotCount
        guard source != last, slotStore.moveSlot(from: source, to: last) else { return }
        UsageEventLog.shared.record("slot_reordenar", detail: "\(source)->fin")
        slotScrollTarget = SlotScrollTarget(index: last)
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
        libraryWorkspace.setActiveLibrary(id: id)
        librarySwitchRevision += 1
        UsageEventLog.shared.record("biblioteca_cambiar", detail: libraryWorkspace.activeLibrary?.name)
    }

    func createLibrary(named name: String) {
        libraryWorkspace.createLibrary(named: name)
        Telemetry.libraryCreated()
        UsageEventLog.shared.record("biblioteca_crear", detail: name)
    }

    @discardableResult
    func deleteLibrary(id: UUID) -> Bool {
        guard libraryWorkspace.deleteLibrary(id: id) else { return false }
        librarySwitchRevision += 1
        UsageEventLog.shared.record("biblioteca_eliminar")
        return true
    }

    func moveLibrary(id: UUID, toIndex index: Int) {
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

    /// Pasa un slot a otra biblioteca. Sin `toOrder` va al primer slot vacío.
    func moveSlotToLibrary(slotIndex: Int, fromLibraryId: UUID? = nil, libraryId: UUID, toOrder: Int? = nil) {
        let source = fromLibraryId ?? libraryWorkspace.workspace.activeLibraryId
        guard ensureCanUseSlot(slotIndex) else { return }
        guard libraryWorkspace.transferSlot(
            fromLibraryId: source, order: slotIndex, toLibraryId: libraryId, toOrder: toOrder
        ) else {
            noEmptySlotFeedback()
            return
        }
        UsageEventLog.shared.record("slot_mover_biblioteca", detail: "\(slotIndex)")
    }

    /// Un ítem del historial soltado sobre otra biblioteca va a su primer slot vacío.
    func saveHistoryItem(_ id: UUID, toLibrary libraryId: UUID) {
        guard let content = historyStore.item(id: id)?.content else { return }
        guard let order = libraryWorkspace.firstEmptyOrder(in: libraryId) else {
            noEmptySlotFeedback()
            return
        }
        guard ensureCanUseSlot(order) else { return }
        libraryWorkspace.saveContent(content, order: order, toLibraryId: libraryId)
        Telemetry.slotSaved(content)
        FeedbackSound.play(.saved)
        UsageEventLog.shared.record("historial_a_biblioteca", detail: "slot_\(order)")
    }

    private func noEmptySlotFeedback() {
        FeedbackSound.play(.pasteFailed)
        showToast("No hay slot vacío en esa biblioteca")
    }

    private func slotDisplayTitle(at index: Int) -> String? {
        let label = slotStore.slot(at: index)?.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let label, !label.isEmpty else { return nil }
        return label
    }
}
