import AppKit
import SwiftUI

/// Barra horizontal que baja desde el notch (o el centro de la barra de menú) al pasar el mouse.
/// El disparo es un monitor global del mouse: no hay ventana invisible tapando la barra de menú.
@MainActor
final class NotchShelfController {
    private let appState: AppState
    private let panelController: PanelController
    private var shelfPanel: NSPanel?
    private var hideWork: DispatchWorkItem?
    /// Con un menú contextual abierto el mouse sale de la barra; no debe cerrarse debajo del menú.
    private var isMenuTracking = false
    private var menuObservers: [NSObjectProtocol] = []
    private var hoverWatch: Timer?
    private var screenObserver: NSObjectProtocol?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var dragDownMonitor: Any?
    private var dragMonitor: Any?
    /// `changeCount` del portapapeles de arrastre al pulsar el botón: si cambia, empezó un arrastre nuevo.
    private var dragChangeCountAtMouseDown = 0
    private var isOpen = false
    private let pointer = NotchShelfPointer()
    private weak var hostingView: NSView?
    /// Ajustes y onboarding abiertos: la barra no se ofrece.
    var isBlocked: () -> Bool = { false }

    /// Con el panel, Ajustes o el onboarding al frente, la barra no tiene sentido.
    private var isSuppressed: Bool { !isEnabled || appState.isPanelVisible || isBlocked() }
    /// Copia del interruptor de Ajustes: se lee en cada movimiento del mouse, así que no se decodifica cada vez.
    private var isEnabled = AppSettings.load().showNotchShelf
    private var settingObserver: NSObjectProtocol?

    init(appState: AppState, panelController: PanelController) {
        self.appState = appState
        self.panelController = panelController
    }

    func start() {
        guard shelfPanel == nil, let screen = anchorScreen() else { return }
        let shelf = makePanel()

        // Ventana de tamaño fijo: solo se anima posición y opacidad, nunca el tamaño.
        let size = NSSize(width: NotchShelfMetrics.panelWidth, height: NotchShelfMetrics.panelHeight)
        let hosting = NSHostingView(
            rootView: NotchShelfView(
                appState: appState,
                pointer: pointer,
                onActivateSlot: { [weak self] index in self?.activate(slot: index) },
                onDropFile: { [weak self] index, url in self?.saveDroppedFile(url, toSlot: index) },
                onOpenPanel: { [weak self] in self?.openPanel() },
                onRenameLibrary: { [weak self] library in self?.renameLibrary(library) },
                onDeleteLibrary: { [weak self] library in self?.deleteLibrary(library) },
                onNewLibrary: { [weak self] in self?.newLibrary() },
                onNewSlot: { [weak self] in self?.newSlot() }
            )
            .environment(appState)
        )
        hostingView = hosting
        hosting.sizingOptions = []
        hosting.safeAreaRegions = []
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]
        let shelfView = NotchShelfHitView { [weak self] inside in
            self?.setPointerInside(inside)
        }
        shelfView.onScroll = { [weak self] direction in self?.appState.notchPageRequest = direction }
        shelfView.frame = hosting.frame
        shelfView.addSubview(hosting)
        shelf.contentView = shelfView
        shelf.setFrame(shelfFrame(on: screen, open: false), display: false)
        shelf.alphaValue = 0
        shelfPanel = shelf

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            Task { @MainActor in self?.mouseMoved() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            Task { @MainActor in self?.mouseMoved() }
            return event
        }
        // Arrastrar un archivo hacia el notch abre la barra para soltarlo en un slot.
        dragDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            Task { @MainActor in
                self?.dragChangeCountAtMouseDown = NSPasteboard(name: .drag).changeCount
            }
        }
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
            Task { @MainActor in self?.fileDragMoved() }
        }
        settingObserver = NotificationCenter.default.addObserver(
            forName: .notchShelfSettingChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isEnabled = AppSettings.load().showNotchShelf
                if !self.isEnabled { self.hide(animated: true, force: true) }
            }
        }
        menuObservers = [
            NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isMenuTracking = true }
            },
            NotificationCenter.default.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.isMenuTracking = false
                    if self.isOpen, !self.pointerIsInShelfZone() { self.scheduleHide() }
                }
            }
        ]
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.placeShelf() }
        }
    }

    /// Slot con contenido: copia o pega según Ajustes. Slot vacío: guarda ahí el portapapeles.
    private func activate(slot index: Int) {
        hide(animated: true, force: true)
        if appState.slotStore.content(at: index) == nil {
            appState.replaceSlotFromClipboard(index: index)
        } else {
            appState.pasteSlot(index: index, panelController: panelController, via: .notch)
        }
    }

    /// El formulario de renombrar vive en el panel: se abre el panel y se le pide el formulario.
    private func renameLibrary(_ library: Library) {
        hide(animated: true, force: true)
        panelController.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [appState] in
            appState.renameLibraryTarget = library
        }
    }

    /// Igual que en el panel: confirma salvo que Ajustes diga lo contrario (la confirmación también vive en el panel).
    private func deleteLibrary(_ library: Library) {
        hide(animated: true, force: true)
        if appState.settings.confirmLibraryDelete {
            panelController.show()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [appState] in
                appState.requestDeleteLibrary(library)
            }
        } else {
            appState.requestDeleteLibrary(library)
        }
    }

    /// «Nuevo slot»: guarda el portapapeles en un slot nuevo (nombre y atajo se editan después en el panel).
    /// La barra queda abierta: el usuario ve el slot nuevo y puede seguir con otra cosa.
    private func newSlot() {
        guard let content = appState.clipboardService.currentContent() else {
            appState.presentNotch(.plain("Nada en el portapapeles"))
            return
        }
        _ = appState.saveToNewSlot(content: content)
    }

    /// El formulario de nueva biblioteca vive en el panel.
    private func newLibrary() {
        hide(animated: true, force: true)
        panelController.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [appState] in
            appState.isNewLibraryFormPresented = true
        }
    }

    private func openPanel() {
        hide(animated: true, force: true)
        panelController.show()
    }

    /// El hover de SwiftUI no llega a un panel que no toma foco: se calcula con la posición real del mouse.
    /// La vista de SwiftUI es "flipped": convertir con ella da coordenadas con origen arriba a la izquierda.
    private func updatePointer() {
        guard isOpen, let shelfPanel, let hostingView else {
            if pointer.location != nil { pointer.location = nil }
            return
        }
        let inWindow = shelfPanel.convertPoint(fromScreen: NSEvent.mouseLocation)
        let inView = hostingView.convert(inWindow, from: nil)
        pointer.location = hostingView.bounds.contains(inView) ? inView : nil
    }

    /// Guarda el archivo soltado en el slot y cierra la barra.
    private func saveDroppedFile(_ url: URL, toSlot index: Int) {
        hide(animated: true, force: true)
        appState.saveToSlot(index: index, content: .fileReference(url: url))
    }

    /// Hay un arrastre de archivos en curso. El portapapeles de arrastre conserva el último arrastre,
    /// así que solo cuenta si cambió desde que se pulsó el botón.
    private func isDraggingFiles() -> Bool {
        let drag = NSPasteboard(name: .drag)
        guard drag.changeCount != dragChangeCountAtMouseDown else { return false }
        return drag.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    }

    private func fileDragMoved() {
        guard !isOpen, !isSuppressed, pointerIsInTriggerZone(), isDraggingFiles() else { return }
        hideWork?.cancel()
        hideWork = nil
        show()
    }

    private func mouseMoved() {
        updatePointer()
        guard !isOpen, !isSuppressed, pointerIsInTriggerZone() else { return }
        hideWork?.cancel()
        hideWork = nil
        show()
    }

    private func setPointerInside(_ inside: Bool) {
        // Con la barra cerrándose no se reabre: solo el notch (o un arrastre de archivo) la abre.
        guard isOpen else { return }
        if inside || pointerIsInShelfZone() {
            hideWork?.cancel()
            hideWork = nil
        } else {
            scheduleHide()
        }
    }

    private func show() {
        guard !isSuppressed else { return }
        guard let shelfPanel, let screen = anchorScreen() else { return }
        startHoverWatch()
        if isOpen { return }
        isOpen = true
        shelfPanel.ignoresMouseEvents = false
        appState.notchOpenCount += 1
        Telemetry.notchOpened()
        let open = shelfFrame(on: screen, open: true)
        let closed = shelfFrame(on: screen, open: false)
        shelfPanel.setFrame(closed, display: false)
        shelfPanel.alphaValue = 0
        shelfPanel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = HotSlotDesign.openDuration
            context.timingFunction = HotSlotDesign.springTiming
            shelfPanel.animator().setFrame(open, display: true)
            shelfPanel.animator().alphaValue = 1
        }
    }

    private func scheduleHide() {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.pointerIsInShelfZone(), !self.isMenuTracking else { return }
            self.hide(animated: true)
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + NotchShelfMetrics.hideDelay, execute: work)
    }

    /// Mientras la barra está abierta, la posición real del mouse manda (el tracking se pierde al taparse).
    private func startHoverWatch() {
        guard hoverWatch == nil else { return }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickHover() }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverWatch = timer
    }

    private func stopHoverWatch() {
        hoverWatch?.invalidate()
        hoverWatch = nil
    }

    private func tickHover() {
        // Se cierra aunque el mouse siga encima.
        if isOpen, isSuppressed {
            hide(animated: true, force: true)
            return
        }
        updatePointer()
        if pointerIsInShelfZone() {
            hideWork?.cancel()
            hideWork = nil
        } else if isOpen, hideWork == nil {
            scheduleHide()
        } else if !isOpen {
            stopHoverWatch()
        }
    }

    /// Zona que abre la barra: el notch (o el centro de la barra de menú), hasta el borde superior.
    private func pointerIsInTriggerZone() -> Bool {
        guard let screen = anchorScreen() else { return false }
        let hit = hitFrame(on: screen)
        let p = NSEvent.mouseLocation
        return p.x >= hit.minX && p.x <= hit.maxX
            && p.y >= hit.minY - 2 && p.y <= screen.frame.maxY + 2
    }

    /// Zona que la mantiene abierta: gatillo + barra, con un margen alrededor.
    private func pointerIsInShelfZone() -> Bool {
        if appState.notchLibraryDragging { return true }
        guard let screen = anchorScreen() else { return false }
        var glass = shelfFrame(on: screen, open: true)
            .insetBy(dx: NotchShelfMetrics.shadowPad, dy: NotchShelfMetrics.shadowPad)
        // La franja del tacho (abajo) no cuenta: solo la usa el arrastre de una biblioteca.
        glass.origin.y += NotchShelfMetrics.trashZone
        glass.size.height -= NotchShelfMetrics.trashZone
        let zone = hitFrame(on: screen)
            .union(glass)
            .insetBy(dx: -8, dy: -6)
        return zone.contains(NSEvent.mouseLocation)
    }

    private func hide(animated: Bool, force: Bool = false) {
        hideWork?.cancel()
        hideWork = nil
        if !force, pointerIsInShelfZone() || isMenuTracking { return }
        guard isOpen, let shelfPanel, let screen = anchorScreen() else { return }
        isOpen = false
        shelfPanel.ignoresMouseEvents = true   // mientras se desvanece no debe reaccionar al mouse
        pointer.location = nil
        let closed = shelfFrame(on: screen, open: false)
        guard animated else {
            shelfPanel.orderOut(nil)
            shelfPanel.setFrame(closed, display: false)
            shelfPanel.alphaValue = 0
            stopHoverWatch()
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = NotchShelfMetrics.closeDuration
            context.timingFunction = HotSlotDesign.closeTiming
            shelfPanel.animator().setFrame(closed, display: true)
            shelfPanel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, !self.isOpen else { return }
                shelfPanel.orderOut(nil)
            }
        })
    }

    private func placeShelf() {
        guard let shelfPanel, let screen = anchorScreen() else { return }
        shelfPanel.setFrame(shelfFrame(on: screen, open: isOpen), display: true)
    }

    /// La pantalla con notch. Si no hay, la que tiene la barra de menú.
    private func anchorScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 24 }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func hitFrame(on screen: NSScreen) -> NSRect {
        let notched = screen.safeAreaInsets.top > 24
        let height = notched ? screen.safeAreaInsets.top : NSStatusBar.system.thickness
        let width: CGFloat = notched ? 220 : 160
        return NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
    }

    /// Mismo tamaño abierta y cerrada. Cerrada queda subida bajo el notch y transparente.
    private func shelfFrame(on screen: NSScreen, open: Bool) -> NSRect {
        let hit = hitFrame(on: screen)
        let width = NotchShelfMetrics.panelWidth
        let height = NotchShelfMetrics.panelHeight
        let x = screen.frame.midX - width / 2
        // El vidrio arranca pegado al borde inferior del notch; el shadowPad absorbe la sombra.
        let openY = hit.minY - height + NotchShelfMetrics.shadowPad
        let y = open ? openY : openY + HotSlotDesign.openSlideOffset
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func makePanel() -> NSPanel {
        let panel = ShelfPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false   // la sombra la dibuja SwiftUI con padding extra en el frame
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.ignoresMouseEvents = false
        return panel
    }
}

/// Panel sin borde que AppKit no recoloca: si no, lo empuja bajo la barra de menú y lo recorta.
private final class ShelfPanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Posición del mouse dentro de la barra (coordenadas de SwiftUI, origen arriba a la izquierda).
@MainActor @Observable
final class NotchShelfPointer {
    var location: CGPoint?
}

private final class NotchShelfHitView: NSView {
    var onInside: (Bool) -> Void
    /// Rueda o trackpad: +1 página siguiente, -1 anterior.
    var onScroll: ((Int) -> Void)?
    private var scrollAccumulator: CGFloat = 0

    init(onInside: @escaping (Bool) -> Void) {
        self.onInside = onInside
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) no soportado")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func scrollWheel(with event: NSEvent) {
        // Vertical (rueda) u horizontal (trackpad): cada ~24 pt acumulados pasan una página.
        let delta = abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX) ? -event.scrollingDeltaY : -event.scrollingDeltaX
        scrollAccumulator += delta
        if event.phase == .ended || event.phase == .cancelled { scrollAccumulator = 0 }
        guard abs(scrollAccumulator) >= 24 else { return }
        onScroll?(scrollAccumulator > 0 ? 1 : -1)
        scrollAccumulator = 0
    }

    override func mouseEntered(with event: NSEvent) { onInside(true) }
    override func mouseExited(with event: NSEvent) { onInside(false) }
}
