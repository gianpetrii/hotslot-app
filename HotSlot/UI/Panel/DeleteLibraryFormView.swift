import SwiftUI

struct DeleteLibraryFormView: View {
    let libraryName: String
    @Binding var dontAskAgain: Bool
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SlotsSpace.m) {
            Text("Eliminar biblioteca")
                .font(SlotsFont.tituloCard)

            Text("«\(libraryName)» y sus 5 slots se borran. Esta acción no se puede deshacer.")
                .font(SlotsFont.textoUI)
                .foregroundStyle(SlotsColor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("No volver a preguntar", isOn: $dontAskAgain)
                .toggleStyle(.checkbox)
                .font(SlotsFont.textoUI)
                .foregroundStyle(SlotsColor.textoSecundario)
                .help("Se puede volver a activar en Ajustes → General")

            HStack {
                Spacer()
                Button("Cancelar", action: onCancel)
                    .buttonStyle(SlotsSecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Eliminar", role: .destructive, action: onDelete)
                    .buttonStyle(SlotsPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(SlotsSpace.l)
        .frame(width: 340)
    }
}
