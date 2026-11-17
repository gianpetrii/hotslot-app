import SwiftUI

/// Aviso negro que sale de la Dynamic Island: «✓ Copiado · {título}» (handoff `04 · Copiado`).
struct CopiedToast: View {
    struct Message: Equatable {
        var label: String
        var detail: String
        var isError = false
    }

    let message: Message
    var width: CGFloat = 300
    var height: CGFloat = 40
    /// Ancho que hay que dejar libre en el centro para la Dynamic Island (0 si no hay).
    var centerGap: CGFloat = 0

    var body: some View {
        HStack(spacing: SlotsSpace.s) {
            Image(systemName: message.isError ? "exclamationmark" : "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(SlotsColor.naranja, in: Circle())
            Text(message.label)
                .slotsText(14)
                .foregroundStyle(.white)
                .fixedSize()
            Spacer(minLength: SlotsSpace.s)
            Text(message.detail)
                .slotsText(14, medium: false)
                .foregroundStyle(Color(slotsHex: 0xCFCAC4))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: centerGap > 0 ? (width - centerGap) / 2 - 2 * SlotsSpace.s : nil, alignment: .trailing)
                .padding(.trailing, SlotsSpace.s)
        }
        .padding(.horizontal, SlotsSpace.s)
        .frame(width: width, height: height)
        .background(.black, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
