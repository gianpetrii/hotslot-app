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
    private var hoverWatch: Timer?
    private var screenObserver: NSObjectProtocol?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isOpen = false
    private let pointer = NotchShelfPointer()
    private weak var hostingView: NSView?
    /// Ajustes y onboarding abiertos: la barra no se ofrece.
    var isBlocked: () -> Bool = { false }

    /// Con el panel, Ajustes o el onboarding al frente, la barra no tiene sentido.
    private var isSuppressed: Bool { appState.isPanelVisible || isBlocked() }

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
                onOpenPanel: { [weak self] in self?.openPanel() }
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
            appState.pasteSlot(index: index, panelController: panelController)
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

    private func mouseMoved() {
        updatePointer()
        guard !isOpen, !isSuppressed, pointerIsInTriggerZone() else { return }
        hideWork?.cancel()
        hideWork = nil
        show()
    }

    private func setPointerInside(_ inside: Bool) {
        if inside || pointerIsInShelfZone() {
            hideWork?.cancel()
            hideWork = nil
            show()
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
            guard let self, !self.pointerIsInShelfZone() else { return }
            self.hide(animated: true)
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: work)
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
        guard let screen = anchorScreen() else { return false }
        let glass = shelfFrame(on: screen, open: true)
            .insetBy(dx: NotchShelfMetrics.shadowPad, dy: NotchShelfMetrics.shadowPad)
        let zone = hitFrame(on: screen)
            .union(glass)
            .insetBy(dx: -20, dy: -16)
        return zone.contains(NSEvent.mouseLocation)
    }

    private func hide(animated: Bool, force: Bool = false) {
        hideWork?.cancel()
        hideWork = nil
        if !force, pointerIsInShelfZone() { return }
        guard isOpen, let shelfPanel, let screen = anchorScreen() else { return }
        isOpen = false
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
            context.duration = HotSlotDesign.closeDuration
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

    override func mouseEntered(with event: NSEvent) { onInside(true) }
    override func mouseExited(with event: NSEvent) { onInside(false) }
}
