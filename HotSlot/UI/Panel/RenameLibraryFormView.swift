import SwiftUI

struct RenameLibraryFormView: View {
    @Binding var name: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SlotsSpace.m) {
            Text("Renombrar biblioteca")
                .font(SlotsFont.tituloCard)

            TextField("Nombre", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(SlotsFont.textoUI)

            HStack {
                Spacer()
                Button("Cancelar", action: onCancel)
                Button("Guardar", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(SlotsSpace.l)
        .frame(width: 320)
    }
}
