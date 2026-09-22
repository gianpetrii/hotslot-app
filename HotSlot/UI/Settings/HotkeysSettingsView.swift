import KeyboardShortcuts
import SwiftUI

struct HotkeysSettingsView: View {
    var body: some View {
        Form {
            Section("Panel") {
                LabeledContent("Abrir / cerrar panel") {
                    KeyboardShortcuts.Recorder(for: .togglePanel)
                }
            }

            Section("Pegar desde slot") {
                ForEach(1...SlotStore.slotCount, id: \.self) { index in
                    LabeledContent("Slot \(index)") {
                        KeyboardShortcuts.Recorder(for: pasteSlotName(index))
                    }
                }
            }

            Section("Guardar en slot") {
                ForEach(1...SlotStore.slotCount, id: \.self) { index in
                    LabeledContent("Slot \(index)") {
                        KeyboardShortcuts.Recorder(for: copyToSlotName(index))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func pasteSlotName(_ index: Int) -> KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.pasteSlotNames[index - 1]
    }

    private func copyToSlotName(_ index: Int) -> KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.copyToSlotNames[index - 1]
    }
}
