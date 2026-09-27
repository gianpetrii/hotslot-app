import KeyboardShortcuts
import SwiftUI

struct HotkeysSettingsView: View {
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section {
                Text("Si un atajo no responde, otra app puede estar usándolo. Grabá uno nuevo o restaurá los valores por defecto.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Panel") {
                HStack {
                    Text("Abrir / cerrar panel")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .togglePanel)
                }
            }

            Section("Pegar desde slot") {
                ForEach(1...SlotStore.slotCount, id: \.self) { index in
                    HStack {
                        Text("Slot \(index)")
                        Spacer()
                        KeyboardShortcuts.Recorder(for: pasteSlotName(index))
                    }
                }
            }

            Section("Guardar en slot") {
                ForEach(1...SlotStore.slotCount, id: \.self) { index in
                    HStack {
                        Text("Slot \(index)")
                        Spacer()
                        KeyboardShortcuts.Recorder(for: copyToSlotName(index))
                    }
                }
            }

            Section {
                Button("Restaurar atajos por defecto", role: .destructive) {
                    showResetConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .confirmationDialog(
            "¿Restaurar todos los atajos?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Restaurar", role: .destructive) {
                KeyboardShortcuts.Name.resetAllToDefaults()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se aplicarán los atajos por defecto (⌘⇧V, pegar ⌘⇧A S D Q W, guardar ⌘⌃ iguales).")
        }
    }

    private func pasteSlotName(_ index: Int) -> KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.pasteSlotNames[index - 1]
    }

    private func copyToSlotName(_ index: Int) -> KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.copyToSlotNames[index - 1]
    }
}
