import AppKit

/// Posicionamiento consistente con el panel flotante (centro del `visibleFrame` de la pantalla del mouse).
enum WindowPlacement {
    static func screenForMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    static func screenContaining(_ frame: NSRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.main
    }

    static func centeredFrame(size: NSSize, on screen: NSScreen?) -> NSRect {
        let screen = screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        return NSRect(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    /// Ajustes tras cerrar el panel: ocupa el mismo lugar que el panel, desplazado un poco arriba-derecha.
    static let settingsWindowSize = NSSize(width: 720, height: 540)

    static func utilityWindowFrame(
        size: NSSize = settingsWindowSize,
        beside panelFrame: NSRect?,
        diagonalRight: CGFloat = 28,
        diagonalUp: CGFloat = 36,
        on screen: NSScreen?
    ) -> NSRect {
        let screen = screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        guard let panelFrame, panelFrame.width > 1, panelFrame.height > 1 else {
            return centeredFrame(size: size, on: screen)
        }

        var origin = NSPoint(
            x: panelFrame.midX - size.width / 2 + diagonalRight,
            y: panelFrame.midY - size.height / 2 + diagonalUp
        )
        origin.x = max(visible.minX + 8, min(origin.x, visible.maxX - size.width - 8))
        origin.y = max(visible.minY + 8, min(origin.y, visible.maxY - size.height - 8))
        return NSRect(origin: origin, size: size)
    }

    static func fadeIn(_ window: NSWindow, duration: TimeInterval = 0.16, completion: (() -> Void)? = nil) {
        window.alphaValue = 0
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = false
            window.animator().alphaValue = 1
        }, completionHandler: completion)
    }

    static func fadeOut(_ window: NSWindow, duration: TimeInterval = 0.18, completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = false
            window.animator().alphaValue = 0
        }, completionHandler: completion)
    }
}
