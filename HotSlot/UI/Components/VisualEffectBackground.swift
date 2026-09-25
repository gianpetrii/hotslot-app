import AppKit
import SwiftUI

/// Fondo con vibrancy nativa. El redondeo va en AppKit: NSVisualEffectView no respeta clipShape de SwiftUI.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> RoundedVisualEffectView {
        let view = RoundedVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.cornerRadius = cornerRadius
        return view
    }

    func updateNSView(_ nsView: RoundedVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
        nsView.cornerRadius = cornerRadius
    }
}

final class RoundedVisualEffectView: NSVisualEffectView {
    var cornerRadius: CGFloat = 0 {
        didSet {
            guard oldValue != cornerRadius else { return }
            applyRounding()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        applyRounding()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) no soportado")
    }

    private func applyRounding() {
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        if cornerRadius > 0 {
            maskImage = Self.stretchableRoundedMask(radius: cornerRadius)
        } else {
            maskImage = nil
        }
    }

    private static func stretchableRoundedMask(radius: CGFloat) -> NSImage {
        let side = radius * 2 + 1
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
