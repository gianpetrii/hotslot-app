import AppKit
import SwiftUI

/// Zona para mover el panel. El window no es movable-by-background para que el drag de slots funcione.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragHandleView {
        WindowDragHandleView()
    }

    func updateNSView(_ nsView: WindowDragHandleView, context: Context) {}
}

final class WindowDragHandleView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Apaga el scroller nativo del ScrollView que lo contiene.
/// Con «Mostrar barras de desplazamiento: siempre», `.scrollIndicators(.hidden)` no alcanza y aparece una barra gruesa
/// encima de la fina propia del panel.
struct HideNativeScrollers: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in Self.apply(from: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in Self.apply(from: nsView) }
    }

    static func apply(from view: NSView?) {
        guard let scroll = view?.enclosingScrollView else { return }
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.scrollerStyle = .overlay
    }
}
