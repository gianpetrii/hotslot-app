import AppKit
import SwiftUI

/// Panel flotante NSPanel con animaciones estilo Spotlight.
@MainActor
final class PanelController: NSWindowController, NSWindowDelegate {
    private let appState: AppState
    private let backdrop = BackdropController()
    private var keyMonitor: Any?
    private var isAnimating = false
    private var openGeneration = 0
    private var targetFrame: NSRect = .zero

    var isVisible: Bool {
        window?.isVisible == true
    }

    init(appState: AppState) {
        self.appState = appState

        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init(window: panel)

        let hosting = NSHostingController(rootView: PanelView(appState: appState, panelController: self))
        hosting.sizingOptions = []
        hosting.safeAreaRegions = []
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.view.layer?.masksToBounds = false
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.delegate = self

        setupKeyMonitor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) no soportado")
    }

    func show() {
        guard let window else { return }
        if isVisible { return }
        isAnimating = false

        let screen = screenForMouse() ?? NSScreen.main
        guard let screen else { return }

        targetFrame = centeredFrame(on: screen)
        backdrop.show(on: screen) { [weak self] in
            self?.hide(animated: true)
        }

        openGeneration += 1
        let generation = openGeneration
        appState.panelBodyRevealed = false

        // Ventana ya del tamaño final y transparente: el redondeo lo dibuja la tarjeta.
        window.setFrame(targetFrame, display: true)
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        isAnimating = true
        appState.isPanelVisible = true
        appState.clipboardService.pollNow()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            guard let self, generation == self.openGeneration else { return }
            self.isAnimating = false
        })
    }

    func hide(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let window, isVisible else {
            completion?()
            return
        }

        openGeneration += 1
        appState.isPanelVisible = false
        appState.panelBodyRevealed = false

        guard animated else {
            window.orderOut(nil)
            backdrop.hide()
            completion?()
            return
        }

        isAnimating = true
        var shrinkFrame = targetFrame.insetBy(dx: HotSlotDesign.closeScaleInset, dy: HotSlotDesign.closeScaleInset)
        shrinkFrame.origin.y += HotSlotDesign.closeSlideOffset

        backdrop.hide()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = HotSlotDesign.closeDuration
            context.timingFunction = HotSlotDesign.closeTiming
            context.allowsImplicitAnimation = true
            window.animator().alphaValue = 0
            window.animator().setFrame(shrinkFrame, display: true)
        } completionHandler: { [weak self] in
            guard let self else { return }
            window.orderOut(nil)
            self.isAnimating = false
            completion?()
        }
    }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // Cerrar solo si el clic fue fuera (backdrop maneja eso); evitar cierre al interactuar con menú bar
    }

    private func screenForMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    private func centeredFrame(on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let size = NSSize(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelHeight)
        return NSRect(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible, self.window?.isKeyWindow == true else { return event }
            if event.keyCode == 53 { // Esc
                self.hide(animated: true)
                return nil
            }
            return event
        }
    }
}

/// NSPanel que puede recibir teclas.
private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
