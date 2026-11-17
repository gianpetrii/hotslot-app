// Dibuja el slot de vidrio de la pantalla de carga de iOS (handoff `F-iOS-00-Carga.html`).
// Uso: swift scripts/render-launch-card.swift
// Genera dos imágenes: la completa (launch screen) y la base sin el cuadradito naranja (la app lo anima encima).
import AppKit
import CoreText

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let fontURL = root.appendingPathComponent("HotSlot/Resources/Fonts/InterTight-Medium.ttf")
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)

// Medidas en puntos. La card mide 196 × 236 y queda centrada en un lienzo con margen para la sombra.
let card = CGSize(width: 196, height: 236)
let margin: CGFloat = 120
let canvas = CGSize(width: card.width + margin * 2, height: card.height + margin * 2)

func render(scale: CGFloat, withSquare: Bool) -> Data {
    let width = Int(canvas.width * scale), height = Int(canvas.height * scale)
    let ctx = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    // Origen arriba a la izquierda, como en el diseño.
    ctx.translateBy(x: 0, y: CGFloat(height))
    ctx.scaleBy(x: scale, y: -scale)
    ctx.translateBy(x: margin, y: margin)

    let rect = CGRect(origin: .zero, size: card)
    let shape = CGPath(roundedRect: rect, cornerWidth: 28, cornerHeight: 28, transform: nil)

    // Sombra: solo por fuera de la card.
    ctx.saveGState()
    ctx.addRect(CGRect(x: -margin, y: -margin, width: canvas.width, height: canvas.height))
    ctx.addPath(shape)
    ctx.clip(using: .evenOdd)
    ctx.setShadow(offset: CGSize(width: 0, height: -30 * scale), blur: 60 * scale,
                  color: CGColor(srgbRed: 90 / 255, green: 25 / 255, blue: 0, alpha: 0.25))
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    ctx.addPath(shape)
    ctx.fillPath()
    ctx.restoreGState()

    // Vidrio y borde.
    ctx.addPath(shape)
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.2))
    ctx.fillPath()
    let border = CGPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerWidth: 27.5, cornerHeight: 27.5, transform: nil)
    ctx.addPath(border)
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55))
    ctx.setLineWidth(1)
    ctx.strokePath()

    // Logo: viewBox de 34 escalado a 116, a 20 pt del borde y 8 pt más abajo.
    ctx.saveGState()
    ctx.translateBy(x: 20, y: 28)
    let unit: CGFloat = 116 / 34
    ctx.scaleBy(x: unit, y: unit)
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(2)
    ctx.addPath(CGPath(roundedRect: CGRect(x: 2, y: 2, width: 12, height: 30), cornerWidth: 4, cornerHeight: 4, transform: nil))
    ctx.addPath(CGPath(roundedRect: CGRect(x: 18, y: 2, width: 14, height: 13), cornerWidth: 4, cornerHeight: 4, transform: nil))
    ctx.strokePath()
    if withSquare {
        ctx.setFillColor(CGColor(srgbRed: 0xE2 / 255, green: 0x50 / 255, blue: 0x1D / 255, alpha: 1))
        ctx.addPath(CGPath(roundedRect: CGRect(x: 18, y: 19, width: 14, height: 13), cornerWidth: 4, cornerHeight: 4, transform: nil))
        ctx.fillPath()
    }
    ctx.restoreGState()

    // «Slots»: 44 pt, interlineado 0,9 y pegado abajo a 20 pt del borde.
    let font = CTFontCreateWithName("InterTight-Medium" as CFString, 44, nil)
    let text = NSAttributedString(string: "Slots", attributes: [
        .font: font,
        .kern: -0.04 * 44,
        .foregroundColor: NSColor.white,
    ])
    let line = CTLineCreateWithAttributedString(text)
    let ascent = CTFontGetAscent(font), descent = CTFontGetDescent(font), leading = CTFontGetLeading(font)
    let lineBox: CGFloat = 0.9 * 44
    let halfLeading = (lineBox - (ascent + descent + leading)) / 2
    let baseline = (card.height - 20 - lineBox) + halfLeading + ascent
    ctx.saveGState()
    ctx.translateBy(x: 20, y: baseline)
    ctx.scaleBy(x: 1, y: -1)
    ctx.textPosition = .zero
    CTLineDraw(line, ctx)
    ctx.restoreGState()

    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

let assets = root.appendingPathComponent("SlotsIOS/Resources/Assets.xcassets")
for (name, withSquare) in [("LaunchCard", true), ("LaunchCardBase", false)] {
    for scale in [2, 3] {
        let url = assets.appendingPathComponent("\(name).imageset/\(name)@\(scale)x.png")
        try! render(scale: CGFloat(scale), withSquare: withSquare).write(to: url)
    }
}
print("Listo: \(Int(canvas.width)) × \(Int(canvas.height)) pt")
