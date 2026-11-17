import SwiftUI

/// Hoja «Nueva biblioteca» (handoff `12`). Devuelve el id de la biblioteca creada.
struct NewLibrarySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var onCreated: (UUID) -> Void = { _ in }

    @State private var name = ""
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isTaken: Bool { !trimmed.isEmpty && model.isLibraryNameTaken(trimmed) }
    private var canCreate: Bool { !trimmed.isEmpty && !isTaken }

    var body: some View {
        VStack(spacing: SlotsSpace.m) {
            SheetHeader(title: "Nueva biblioteca", size: 36) { dismiss() }
            VStack(spacing: SlotsSpace.s) {
                FieldLabel(text: "Nombre")
                SheetTextField(placeholder: "", text: $name, isFocused: focused)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(create)
            }
            Text(isTaken ? "Ya tenés una biblioteca con ese nombre." : "Ejemplos: Música, Facturación, Redes, Cliente Acme.")
                .slotsText(13, medium: false)
                .foregroundStyle(isTaken ? SlotsColor.rosadoTexto : SlotsColor.textoSecundario)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            SheetPrimaryButton(title: "Crear biblioteca", action: create)
                .disabled(!canCreate)
        }
        .padding(.horizontal, SlotsSpace.m)
        .padding(.top, 28)
        .padding(.bottom, SlotsSpace.s)
        .onAppear { focused = true }
        .slotsSheetStyle(detents: [.height(330)])
    }

    private func create() {
        guard canCreate, let id = model.createLibrary(named: trimmed) else { return }
        onCreated(id)
        dismiss()
    }
}
