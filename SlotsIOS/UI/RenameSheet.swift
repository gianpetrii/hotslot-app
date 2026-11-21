import SwiftUI
import UniformTypeIdentifiers

/// Qué se renombra desde la pantalla principal.
enum RenameRequest: Identifiable {
    case library(Library)
    /// `isNew`: slot recién creado con «Nuevo slot»; si se cierra sin nombre, se descarta.
    case slot(SlotRecord, isNew: Bool)

    var id: UUID {
        switch self {
        case .library(let library): return library.id
        case .slot(let slot, _): return slot.id
        }
    }
}

/// Hoja para renombrar una biblioteca o un slot, con el mismo estilo que «Nueva biblioteca».
struct RenameSheet: View {
    let title: String
    let label: String
    let initialName: String
    /// Mensaje de error si el nombre no sirve (por ejemplo, repetido).
    var error: (String) -> String? = { _ in nil }
    let onSave: (String) -> Void
    var onCancel: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var saved = false
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var errorText: String? { trimmed.isEmpty ? nil : error(trimmed) }
    private var canSave: Bool { !trimmed.isEmpty && errorText == nil }

    var body: some View {
        VStack(spacing: SlotsSpace.m) {
            SheetHeader(title: title, size: 36) { dismiss() }
            VStack(spacing: SlotsSpace.s) {
                FieldLabel(text: label)
                SheetTextField(placeholder: "", text: $name, isFocused: focused)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(save)
            }
            if let errorText {
                Text(errorText)
                    .slotsText(13, medium: false)
                    .foregroundStyle(SlotsColor.rosadoTexto)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            SheetPrimaryButton(title: "Guardar", action: save)
                .disabled(!canSave)
        }
        .padding(.horizontal, SlotsSpace.m)
        .padding(.top, 28)
        .padding(.bottom, SlotsSpace.s)
        .onAppear {
            name = initialName
            focused = true
        }
        .onDisappear { if !saved { onCancel() } }
        .slotsSheetStyle(detents: [.height(errorText == nil ? 300 : 330)])
    }

    private func save() {
        guard canSave else { return }
        saved = true
        onSave(trimmed)
        dismiss()
    }
}

/// Confirmación para eliminar una biblioteca, con el estilo de las hojas de la app.
struct ConfirmDeleteSheet: View {
    let title: String
    let message: String
    let confirmTitle: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: SlotsSpace.m) {
            Text(title)
                .slotsText(30, tracking: -0.03, lineHeight: 1.05)
                .foregroundStyle(SlotsColor.tinta)
            Text(message)
                .slotsText(15, medium: false, lineHeight: 1.4)
                .foregroundStyle(SlotsColor.textoTerciario)
            Spacer(minLength: 0)
            Button {
                dismiss()
                onConfirm()
            } label: {
                Text(confirmTitle)
                    .slotsText(17)
                    .foregroundStyle(SlotsColor.rosadoTexto)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(SlotsColor.rosado, in: Capsule())
            }
            .buttonStyle(.plain)
            Button { dismiss() } label: {
                Text("Cancelar")
                    .slotsText(17)
                    .foregroundStyle(SlotsColor.tinta)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(SlotsColor.botonSecundario, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, SlotsSpace.m)
        .padding(.top, 28)
        .padding(.bottom, SlotsSpace.s)
        .slotsSheetStyle(detents: [.height(340)])
    }
}

extension UTType {
    /// Slot arrastrado dentro de Slots.
    static let slotsSlotDrag = UTType(exportedAs: "com.hotslot.app.slot-drag", conformingTo: .data)
    /// Biblioteca (pill) arrastrada dentro de Slots.
    static let slotsLibraryDrag = UTType(exportedAs: "com.hotslot.app.library-drag", conformingTo: .data)
}
