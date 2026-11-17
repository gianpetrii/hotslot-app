import SwiftUI

extension SlotsColor {
    static let rosado = Color(slotsHex: 0xFFE3D7)
    static let rosadoTexto = Color(slotsHex: 0xA3330A)
    static let naranjaClaro = Color(slotsHex: 0xF2804F)
}

/// Etiqueta chica sobre un campo («Tipo», «Nombre de la tarjeta»…).
struct FieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .slotsText(13)
            .foregroundStyle(SlotsColor.textoSecundario)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Título de hoja con botón de cerrar (×).
struct SheetHeader: View {
    let title: String
    var size: CGFloat = 44
    let onClose: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .slotsText(size, tracking: -0.04, lineHeight: 1)
                .foregroundStyle(SlotsColor.tinta)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: SlotsSpace.s)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SlotsColor.tinta)
                    .frame(width: 48, height: 48)
                    .background(SlotsColor.botonSecundario, in: Circle())
            }
            .accessibilityLabel("Cerrar")
        }
    }
}

/// Botón principal de las hojas: negro, con la flecha en un círculo blanco.
struct SheetPrimaryButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).slotsText(18)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SlotsColor.tinta)
                    .frame(width: 48, height: 48)
                    .background(.white, in: Circle())
            }
            .foregroundStyle(.white)
            .padding(.leading, 24)
            .padding(.trailing, 8)
            .frame(height: 64)
            .background(SlotsColor.tinta, in: Capsule())
            .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
    }
}

/// Campo de texto blanco redondeado. Con foco marca el borde en negro.
struct SheetTextField: View {
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool
    var keyboard: UIKeyboardType = .default

    var body: some View {
        TextField(placeholder, text: $text)
            .font(SlotsFont.medium(18))
            .foregroundStyle(SlotsColor.tinta)
            .keyboardType(keyboard)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(.white, in: RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous)
                    .strokeBorder(SlotsColor.tinta, lineWidth: 2)
                    .opacity(isFocused ? 1 : 0)
            }
    }
}

/// Card oscura «En tu portapapeles». No muestra el contenido: leerlo dispara el aviso de pegado del sistema.
struct ClipboardCard: View {
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("En tu portapapeles").foregroundStyle(SlotsColor.textoSobreOscuro)
                    Spacer()
                    Text(actionTitle).foregroundStyle(SlotsColor.naranjaClaro)
                }
                .slotsText(13)
                Text("Tenés algo copiado")
                    .slotsText(22, tracking: -0.02, lineHeight: 1.1)
                    .foregroundStyle(.white)
            }
            .padding(SlotsSpace.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SlotsColor.tinta, in: RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("En tu portapapeles: tenés algo copiado. \(actionTitle)")
    }
}

/// Pills para elegir biblioteca dentro de una hoja, con «+» para crear una.
struct LibraryPicker: View {
    let libraries: [Library]
    @Binding var selection: UUID
    let onAdd: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SlotsSpace.s) {
                ForEach(libraries) { library in
                    let isSelected = library.id == selection
                    Button { selection = library.id } label: {
                        Text(library.name)
                            .slotsText(14)
                            .foregroundStyle(isSelected ? .white : SlotsColor.tinta)
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .background(isSelected ? SlotsColor.tinta : .white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SlotsColor.textoTerciario)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Circle().strokeBorder(SlotsColor.bordePunteado, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        }
                }
                .accessibilityLabel("Nueva biblioteca")
            }
        }
    }
}

extension View {
    /// Presentación común de las hojas: fondo papel, esquinas de 34 y manija.
    func slotsSheetStyle(detents: Set<PresentationDetent> = [.large]) -> some View {
        presentationDetents(detents)
            .presentationDragIndicator(.visible)
            .presentationBackground(SlotsColor.papel)
            .presentationCornerRadius(34)
            .preferredColorScheme(.light)
    }
}
