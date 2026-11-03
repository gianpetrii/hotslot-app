import KeyboardShortcuts
import SwiftUI

/// Grabador compacto de atajos de un slot (pegar + guardar) desde el panel.
struct SlotShortcutEditorPopover: View {
    let slotIndex: Int
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var pasteName: KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.pasteSlotNames[slotIndex - 1]
    }

    private var copyName: KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.copyToSlotNames[slotIndex - 1]
    }

    var body: some View {
        ShortcutRecorderPopoverLayout(width: 268) {
            VStack(alignment: .leading, spacing: SlotsSpace.s) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Atajos del slot \(slotIndex)")
                        .font(SlotsFont.textoUI.weight(.semibold))
                        .foregroundStyle(SlotsColor.tinta)

                    Text("Al cerrar el panel vuelven los atajos globales.")
                        .font(SlotsFont.etiqueta)
                        .foregroundStyle(SlotsColor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: SlotsSpace.s) {
                    ShortcutRecorderRow(title: "Pegar", name: pasteName)
                    ShortcutRecorderRow(title: "Guardar", name: copyName)
                }
                .padding(.top, 2)

                Button("Todos los atajos en Ajustes…") {
                    dismiss()
                    appState.pendingSettingsTab = .hotkeys
                    appState.openSettings?()
                }
                .font(SlotsFont.etiqueta)
                .foregroundStyle(SlotsColor.naranja)
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .onAppear {
            KeyboardShortcuts.disable(KeyboardShortcuts.Name.allShortcutNames)
        }
        .onDisappear {
            appState.hotkeyManager.reloadFromStorage()
            appState.noteShortcutsChanged()
        }
    }
}
