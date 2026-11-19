import AppKit
import SwiftUI

/// Silueta de la barra del notch: un cuello del ancho del notch que sube hasta el borde de la pantalla
/// y, debajo de la barra de menú, el cuerpo ancho. Las dos uniones son curvas hacia afuera, así la barra
/// parece colgar del techo y los menús de las apps (a los costados del notch) quedan libres.
struct NotchGlassShape: Shape {
    /// Ancho del cuello: el del notch (o del centro de la barra de menú si no hay notch).
    var neckWidth: CGFloat
    /// Alto del cuello: hasta donde termina la barra de menú.
    var neckHeight: CGFloat
    var fillet: CGFloat = 16
    var corner: CGFloat = NotchShelfMetrics.shelfCorner

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let cx = rect.midX
        let nl = cx - neckWidth / 2
        let nr = cx + neckWidth / 2
        let y2 = min(neckHeight, h - corner * 2)
        let f = min(fillet, max(y2, 1))

        var p = Path()
        p.move(to: CGPoint(x: nl, y: rect.minY))
        p.addLine(to: CGPoint(x: nl, y: y2 - f))
        p.addQuadCurve(to: CGPoint(x: nl - f, y: y2), control: CGPoint(x: nl, y: y2))
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: y2), tangent2End: CGPoint(x: rect.minX, y: y2 + corner), radius: corner)
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: h), tangent2End: CGPoint(x: rect.minX + corner, y: h), radius: corner)
        p.addArc(tangent1End: CGPoint(x: w, y: h), tangent2End: CGPoint(x: w, y: h - corner), radius: corner)
        p.addArc(tangent1End: CGPoint(x: w, y: y2), tangent2End: CGPoint(x: w - corner, y: y2), radius: corner)
        p.addLine(to: CGPoint(x: nr + f, y: y2))
        p.addQuadCurve(to: CGPoint(x: nr, y: y2 - f), control: CGPoint(x: nr, y: y2))
        p.addLine(to: CGPoint(x: nr, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// Vidrio nativo recortado con la silueta del notch (el redondeo de SwiftUI no alcanza a `NSVisualEffectView`).
struct ShapedVisualEffectBackground: NSViewRepresentable {
    var shape: NotchGlassShape
    var size: CGSize

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.maskImage = mask()
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.maskImage = mask()
    }

    private func mask() -> NSImage {
        let cgPath = shape.path(in: CGRect(origin: .zero, size: size)).cgPath
        return NSImage(size: size, flipped: true) { _ in
            NSColor.black.setFill()
            NSBezierPath(cgPath: cgPath).fill()
            return true
        }
    }
}
