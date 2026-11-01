import SwiftUI

/// Cuando los 5 slots están llenos: elegir cuál reemplazar (handoff Mac 08).
struct SaveClipboardSlotPickerSheet: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var replaceIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: SlotsSpace.m) {
            Text("Guardar portapapeles")
                .font(SlotsFont.tituloCard)

            Text("Todos los slots tienen contenido. Elegí cuál reemplazar; lo anterior pasa al historial.")
                .font(SlotsFont.textoUI)
                .foregroundStyle(SlotsColor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: SlotsSpace.s) {
                ForEach(appState.slotStore.slots) { slot in
                    Button {
                        if slot.content == nil {
                            appState.saveClipboardToSlot(slot.index, replaceExisting: false)
                            dismiss()
                        } else {
                            replaceIndex = slot.index
                        }
                    } label: {
                        HStack {
                            Text("Slot \(slot.index)")
                                .font(SlotsFont.etiqueta)
                                .foregroundStyle(SlotsColor.textoSecundario)
                                .frame(width: 56, alignment: .leading)
                            Text(SlotCardCopy.displayTitle(for: slot))
                                .font(SlotsFont.textoUI)
                                .foregroundStyle(SlotsColor.tinta)
                                .lineLimit(1)
                            Spacer()
                            if slot.content != nil {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(SlotsColor.naranja)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: SlotsRadius.chip, style: .continuous)
                                .fill(SlotsColor.teclaFondo)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
            }
        }
        .padding(SlotsSpace.l)
        .frame(width: 400)
        .alert(
            "¿Reemplazar \"\(replaceTitle)\"?",
            isPresented: Binding(
                get: { replaceIndex != nil },
                set: { if !$0 { replaceIndex = nil } }
            )
        ) {
            Button("Cancelar", role: .cancel) { replaceIndex = nil }
            Button("Reemplazar", role: .destructive) {
                if let index = replaceIndex {
                    appState.saveClipboardToSlot(index, replaceExisting: true)
                    replaceIndex = nil
                    dismiss()
                }
            }
        } message: {
            Text("Lo que tenía el slot queda en el historial por si lo necesitás.")
        }
    }

    private var replaceTitle: String {
        guard let index = replaceIndex,
              let slot = appState.slotStore.slot(at: index) else { return "este slot" }
        return SlotCardCopy.displayTitle(for: slot)
    }
}
