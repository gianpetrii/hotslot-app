import KeyboardShortcuts
import SwiftUI

/// Contenedor de popover con ancho fijo; alto opcional (si es nil, crece con el contenido).
struct ShortcutRecorderPopoverLayout<Content: View>: View {
    let width: CGFloat
    var height: CGFloat?
    @ViewBuilder var content: () -> Content

    init(width: CGFloat, height: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.width = width
        self.height = height
        self.content = content
    }

    var body: some View {
        Group {
            if let height {
                content()
                    .frame(width: width, height: height, alignment: .topLeading)
            } else {
                content()
                    .frame(width: width, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, SlotsSpace.m)
        .padding(.vertical, SlotsSpace.s)
        .background {
            RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous)
                .fill(SlotsColor.papel)
                .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
        }
    }
}

struct ShortcutRecorderRow: View {
    let title: String
    let name: KeyboardShortcuts.Name

    var body: some View {
        HStack(alignment: .center, spacing: SlotsSpace.s) {
            Text(title)
                .font(SlotsFont.etiqueta)
                .foregroundStyle(SlotsColor.textoSecundario)
                .lineLimit(2)
                .frame(width: 92, alignment: .leading)

            KeyboardShortcuts.Recorder(for: name)
                .frame(width: HotSlotDesign.shortcutBadgeWidthRegular + 36, alignment: .trailing)
                .frame(minHeight: 28)
                .padding(.horizontal, SlotsSpace.s)
                .padding(.vertical, 3)
                .background {
                    RoundedRectangle(cornerRadius: SlotsRadius.chip, style: .continuous)
                        .fill(SlotsColor.teclaFondo)
                }
        }
        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
    }
}
