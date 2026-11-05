import SwiftUI

/// Formulario de nueva biblioteca (popover / overlay del panel).
struct NewLibraryFormView: View {
    @Binding var name: String
    let onCancel: () -> Void
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SlotsSpace.m) {
            Text("Nueva biblioteca")
                .font(SlotsFont.tituloCard)

            TextField("Nombre", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(SlotsFont.textoUI)

            HStack {
                Spacer()
                Button("Cancelar", action: onCancel)
                    .buttonStyle(SlotsSecondaryButtonStyle())
                Button("Crear biblioteca", action: onCreate)
                    .buttonStyle(SlotsPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(SlotsSpace.l)
        .frame(width: 320)
    }
}
