import SwiftUI

/// Renombrar slot (mismo lenguaje que `NewLibraryFormView`, no alert del sistema).
struct RenameSlotFormView: View {
    @Binding var title: String
    let slotIndex: Int
    let onCancel: () -> Void
    let onSave: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SlotsSpace.m) {
            Text("Renombrar slot \(slotIndex)")
                .font(SlotsFont.tituloCard)

            TextField("Título", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(SlotsFont.textoUI)
                .focused($isFocused)

            HStack {
                Spacer()
                Button("Cancelar", action: onCancel)
                Button("Guardar", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(SlotsSpace.l)
        .frame(width: 320)
        .onAppear {
            isFocused = true
        }
    }
}
