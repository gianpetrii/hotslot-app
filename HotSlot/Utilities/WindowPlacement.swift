import AppKit

/// Posicionamiento consistente con el panel flotante (centro del `visibleFrame` de la pantalla del mouse).
enum WindowPlacement {
    static func screenForMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
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
