import SwiftUI

/// Card de un slot en la grilla (handoff `F-iOS-02-Slots` y `F-iOS-04-Copiado`).
struct SlotCardView: View {
    let slot: SlotRecord
    /// Recién copiada: naranja con «Copiado ✓».
    var isCopied = false
    /// Modo Editar: muestra el asa en lugar del lápiz.
    var showsHandle = false
    /// Modo Editar: cruz a la izquierda para vaciar (o eliminar) el slot.
    var showsCross = false
    /// Destino de un arrastre: borde naranja punteado.
    var isDropTarget = false

    private var content: ClipContent? { slot.clipContent() }
    private var isEmpty: Bool { content == nil }

    private var imageFileName: String? {
        if case .image(let fileName) = content { return fileName }
        return nil
    }

    /// Las imágenes verticales ocupan dos filas.
    static func rowSpan(for slot: SlotRecord) -> Int {
        guard case .image(let fileName) = slot.clipContent(),
              let size = SlotImageLoader.pixelSize(fileName: fileName), size.width > 0 else { return 1 }
        return size.height / size.width > 1.15 ? 2 : 1
    }

    /// Color propio de un slot de color, o el fondo elegido en el Mac.
    private var backgroundHex: String? {
        if case .text(let string) = content, let hex = SlotCardText.hexColor(string) { return hex }
        return slot.cardBackgroundHex
    }

    private var usesLightContent: Bool {
        if imageFileName != nil { return true }
        return SlotsPalette.prefersLightContent(hexString: backgroundHex)
    }

    private var primary: Color { usesLightContent ? .white : SlotsColor.tinta }

    private var secondary: Color {
        if imageFileName != nil { return .white }
        return usesLightContent ? .white.opacity(0.72) : SlotsColor.textoSecundario
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                if showsCross && !isCopied {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(SlotsColor.tinta)
                        .frame(width: 28, height: 28)
                        .background(usesLightContent ? Color.white.opacity(0.9) : SlotsColor.botonSecundario, in: Circle())
                        .overlay { Circle().strokeBorder(SlotsColor.linea, lineWidth: isEmpty ? 1 : 0) }
                }
                Text(isEmpty ? "Slot \(slot.order)" : "\(SlotCardText.kindLabel(slot))\n\(SlotCardText.detail(slot))")
                    .slotsText(12, lineHeight: 1.2)
                    .foregroundStyle(secondary)
                    .lineLimit(2)
                Spacer(minLength: SlotsSpace.s)
                if isCopied {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(usesLightContent ? SlotsColor.naranja : .white)
                        .frame(width: 24, height: 24)
                        .background(usesLightContent ? Color.white : SlotsColor.naranja, in: Circle())
                } else if showsHandle {
                    Image(systemName: "circle.grid.2x2.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(SlotsColor.tinta)
                        .frame(width: 28, height: 28)
                        .background(usesLightContent ? Color.white.opacity(0.9) : SlotsColor.botonSecundario, in: Circle())
                        .overlay { Circle().strokeBorder(SlotsColor.linea, lineWidth: isEmpty ? 1 : 0) }
                } else if !isEmpty {
                    // Lápiz: abre el editor sin pasar por el menú. El toque lo recibe un botón aparte.
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(primary)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: SlotsSpace.s)
            Text(isCopied ? "Copiado" : isEmpty ? (SlotCardText.customTitle(slot) ?? "Vacío") : SlotCardText.title(slot))
                .slotsText(26, tracking: -0.035, lineHeight: 0.95)
                .foregroundStyle(isEmpty ? SlotsColor.textoSecundario : primary)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
        }
        .padding(SlotsSpace.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background { background }
        .clipShape(RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous))
        .overlay {
            if isEmpty {
                RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous)
                    .strokeBorder(SlotsColor.bordePunteado, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
        }
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous)
                    .strokeBorder(SlotsColor.naranja, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isCopied || isEmpty ? "" : "Toca dos veces para copiar")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var background: some View {
        if isEmpty {
            Color.clear
        } else if let imageFileName {
            GeometryReader { proxy in
                ZStack {
                    SlotsColor.cardOscura
                    if let image = SlotImageLoader.thumbnail(fileName: imageFileName, maxPixel: 900) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    }
                    // Sombra suave arriba y abajo para que el texto se lea sobre cualquier imagen.
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.35), location: 0),
                            .init(color: .clear, location: 0.35),
                            .init(color: .clear, location: 0.55),
                            .init(color: .black.opacity(0.5), location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                }
            }
        } else if SlotsPalette.isBrandGradient(backgroundHex) {
            Image("DegradeNaranja").resizable().scaledToFill()
        } else if let color = SlotsPalette.color(hexString: backgroundHex) {
            color
        } else {
            Color.white
        }
    }

    private var accessibilityLabel: String {
        if isCopied { return "\(SlotCardText.title(slot)), copiado" }
        if isEmpty { return "\(SlotCardText.title(slot)), vacío" }
        return "Copiar \(SlotCardText.title(slot)), \(SlotCardText.kindLabel(slot))"
    }
}

/// Al apoyar el dedo la card baja a 0,96 y marca un borde naranja (handoff `03 · Tocando`).
struct SlotCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous)
                    .strokeBorder(SlotsColor.naranja, lineWidth: 2)
                    .opacity(configuration.isPressed ? 1 : 0)
            }
            // Con «Reducir movimiento» no se achica: solo aparece el borde.
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension SlotsColor {
    /// Borde punteado de los slots vacíos y del botón «+» de bibliotecas.
    static let bordePunteado = Color(slotsHex: 0xB5B5B0)
    /// Fondo del botón secundario de la cabecera.
    static let botonSecundario = Color(slotsHex: 0xE2E2DF)
}
