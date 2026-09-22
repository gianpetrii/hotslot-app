import AppKit
import SwiftUI

/// Panel flotante NSPanel con contenido SwiftUI.
@MainActor
final class PanelController: NSWindowController {
    private let appState: AppState
    private var keyMonitor: Any?

    var isVisible: Bool {
        window?.isVisible == true
    }

    init(appState: AppState) {
        self.appState = appState

        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .hudWindow],
            backing: .buffered,
            defer: false
        )

        super.init(window: panel)

        let hosting = NSHostingController(rootView: PanelView(appState: appState, panelController: self))
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

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
    }

    func hide() {
        window?.orderOut(nil)
    }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    private func positionNearCursor() {
        guard let screen = NSScreen.main else { return }
        let mouse = NSEvent.mouseLocation
        let panelSize = window?.frame.size ?? NSSize(width: 420, height: 480)
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
                self.appState.isPanelVisible = false
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
