import SwiftUI

/// Cuando los 5 slots están llenos: elegir cuál reemplazar (handoff Mac 08).
struct SaveClipboardSlotPickerSheet: View {
    @Bindable var appState: AppState
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
                            closePicker()
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

            if replaceIndex != nil {
                VStack(alignment: .leading, spacing: SlotsSpace.xs) {
                    Text("¿Reemplazar «\(replaceTitle)»?")
                        .font(SlotsFont.textoUI)
                        .foregroundStyle(SlotsColor.tinta)
                    Text("Lo que tenía el slot queda en el historial por si lo necesitás.")
                        .font(SlotsFont.etiqueta)
                        .foregroundStyle(SlotsColor.textoSecundario)
                }
                .transition(.opacity)
            }

            HStack {
                Spacer()
                if let index = replaceIndex {
                    Button("Cancelar") { replaceIndex = nil }
                        .buttonStyle(SlotsSecondaryButtonStyle())
                        .keyboardShortcut(.cancelAction)
                    Button("Reemplazar") {
                        appState.saveClipboardToSlot(index, replaceExisting: true)
                        replaceIndex = nil
                        closePicker()
                    }
                    .buttonStyle(SlotsPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Cancelar", action: closePicker)
                        .buttonStyle(SlotsSecondaryButtonStyle())
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .padding(SlotsSpace.l)
        .frame(width: 400)
        .animation(.easeOut(duration: 0.16), value: replaceIndex)
    }

    private func closePicker() {
        appState.isSaveClipboardSlotPickerPresented = false
    }

    private var replaceTitle: String {
        guard let index = replaceIndex,
              let slot = appState.slotStore.slot(at: index) else { return "este slot" }
        return SlotCardCopy.displayTitle(for: slot)
    }
}
