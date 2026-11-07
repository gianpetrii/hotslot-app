import SwiftUI

/// Preview flotante de un slot. No cambia el tamaño de la tarjeta.
struct SlotPeekView: View {
    let content: ClipContent

    var body: some View {
        Group {
            switch content {
            case .image(let fileName):
                ClipThumbnailView(fileName: fileName, style: .peek)
            case .text(let string):
                textPeek(string.trimmingCharacters(in: .whitespacesAndNewlines))
            case .file:
                SlotFileBlock(content: content, iconSize: 96, ink: SlotsColor.tinta, secondaryInk: SlotsColor.textoSecundario, nameLines: 2)
                    .frame(width: HotSlotDesign.slotPeekWidth - 20, alignment: .leading)
            }
        }
        .padding(10)
    }

    @ViewBuilder
    private func textPeek(_ string: String) -> some View {
        let body = Text(string)
            .font(HotSlotTypography.rowPrimary)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)

        ViewThatFits(in: .vertical) {
            body
            ScrollView {
                body
            }
        }
        .frame(width: HotSlotDesign.slotPeekWidth)
        .frame(maxHeight: HotSlotDesign.slotPeekMaxTextHeight, alignment: .top)
    }
}
