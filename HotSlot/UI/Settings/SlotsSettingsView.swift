import SwiftUI

struct SlotsSettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        Form {
            ForEach(appState.slotStore.slots) { slot in
                Section(slot.label) {
                    TextField("Etiqueta", text: binding(for: slot.index))
                    if let content = slot.content {
                        Text(content.previewText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Vacío")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    HStack {
                        Button("Guardar clipboard actual") {
                            if let content = appState.clipboardService.currentContent() {
                                appState.saveToSlot(index: slot.index, content: content)
                            }
                        }
                        if slot.content != nil {
                            Button("Limpiar", role: .destructive) {
                                appState.slotStore.clearSlot(index: slot.index)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { appState.slotStore.slot(at: index)?.label ?? "" },
            set: { appState.slotStore.updateLabel(index: index, label: $0) }
        )
    }
}
