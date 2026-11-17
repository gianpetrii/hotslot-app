import SwiftUI

/// Biblioteca sin nada guardado (handoff `01 · Primera vez` y `13 · Biblioteca vacía`).
struct EmptyLibraryView: View {
    /// `nil` en la primera vez: «Tu primer slot». Si no, «{nombre} está vacía».
    let libraryName: String?
    /// Hay algo en el portapapeles (detectado sin leerlo).
    var clipboardAvailable = false
    var onUseClipboard: () -> Void = {}

    var body: some View {
        VStack(spacing: SlotsSpace.s) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Slot 1\nVacío")
                    .slotsText(12, lineHeight: 1.2)
                    .foregroundStyle(SlotsColor.textoSecundario)
                Spacer(minLength: SlotsSpace.s)
                VStack(alignment: .leading, spacing: 10) {
                    Text(libraryName.map { "\($0) está vacía" } ?? "Tu primer\nslot")
                        .slotsText(32, tracking: -0.035, lineHeight: 0.95)
                        .foregroundStyle(SlotsColor.tinta)
                    Text("Guardá acá lo que mandás todos los días: un link, una respuesta, una imagen.")
                        .slotsText(15, medium: false, lineHeight: 1.4)
                        .foregroundStyle(SlotsColor.textoTerciario)
                }
            }
            .padding(SlotsSpace.m)
            .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
            .overlay {
                RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous)
                    .strokeBorder(SlotsColor.bordePunteado, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }

            if clipboardAvailable {
                ClipboardCard(actionTitle: "Guardar como slot", action: onUseClipboard)
            }

            Text("O tocá + para crear uno desde cero")
                .slotsText(13, medium: false)
                .foregroundStyle(SlotsColor.textoSecundario)
                .padding(.top, SlotsSpace.s)
        }
    }
}
