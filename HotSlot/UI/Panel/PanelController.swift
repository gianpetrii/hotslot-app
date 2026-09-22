import AppKit
import SwiftUI

/// Panel flotante NSPanel con contenido SwiftUI.
@MainActor
final class PanelController: NSWindowController, NSWindowDelegate {
    private let appState: AppState
    private var keyMonitor: Any?

    var isVisible: Bool {
        window?.isVisible == true
    }

    init(appState: AppState) {
        self.appState = appState

        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .hudWindow],
            backing: .buffered,
            defer: false
        )

        super.init(window: panel)

        let hosting = NSHostingController(rootView: PanelView(appState: appState, panelController: self))
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = true
        panel.delegate = self

        setupKeyMonitor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) no soportado")
    }

    func show() {
        positionNearCursor()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        appState.isPanelVisible = true
        appState.clipboardService.pollNow()
    }

    func hide() {
        window?.orderOut(nil)
        appState.isPanelVisible = false
    }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func positionNearCursor() {
        guard let screen = NSScreen.main else { return }
        let mouse = NSEvent.mouseLocation
        let panelSize = window?.frame.size ?? NSSize(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelHeight)
        var origin = NSPoint(
            x: mouse.x - panelSize.width / 2,
            y: mouse.y - panelSize.height - 20
        )
        let visible = screen.visibleFrame
        origin.x = max(visible.minX, min(origin.x, visible.maxX - panelSize.width))
        origin.y = max(visible.minY, min(origin.y, visible.maxY - panelSize.height))
        window?.setFrameOrigin(origin)
    }

    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible else { return event }
            if event.keyCode == 53 { // Esc
                self.hide()
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
