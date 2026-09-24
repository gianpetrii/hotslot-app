import AppKit

/// Dim sutil a pantalla completa detrás del panel (como Spotlight, sin blur pesado).
@MainActor
final class BackdropController {
    private var window: NSPanel?
    private var clickHandler: (() -> Void)?

    var isVisible: Bool { window?.isVisible == true }

    func show(on screen: NSScreen, onClick: @escaping () -> Void) {
        clickHandler = onClick
        let frame = screen.frame

        if window == nil {
            let panel = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.isReleasedWhenClosed = false
            panel.ignoresMouseEvents = false

            let container = BackdropView(frame: frame)
            container.onClick = { [weak self] in self?.clickHandler?() }
            panel.contentView = container
            window = panel
        }

        window?.setFrame(frame, display: true)
        window?.alphaValue = 0
        window?.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = HotSlotDesign.openDuration
            context.timingFunction = HotSlotDesign.springTiming
            window?.animator().alphaValue = 1
        }
    }

    func hide(completion: (() -> Void)? = nil) {
        guard let window, window.isVisible else {
            completion?()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = HotSlotDesign.closeDuration
            context.timingFunction = HotSlotDesign.closeTiming
            window.animator().alphaValue = 0
        } completionHandler: {
            window.orderOut(nil)
            completion?()
        }
    }
}

/// Capa de oscurecimiento ligero; clic para cerrar.
private final class BackdropView: NSView {
    var onClick: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.08).cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) no soportado")
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
