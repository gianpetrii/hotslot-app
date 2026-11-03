import SwiftUI

struct DeleteLibraryFormView: View {
    let libraryName: String
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

            HStack {
                Spacer()
                Button("Cancelar", action: onCancel)
                Button("Eliminar", role: .destructive, action: onDelete)
            }
        }
        .padding(SlotsSpace.l)
        .frame(width: 340)
    }
}
