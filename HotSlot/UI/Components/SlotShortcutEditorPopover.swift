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
        ShortcutRecorderPopoverLayout(width: 320, height: 300) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Al cerrar este panel los atajos globales se activan de nuevo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ShortcutRecorderRow(title: "Pegar slot \(slotIndex)", name: pasteName)
                ShortcutRecorderRow(title: "Guardar en slot \(slotIndex)", name: copyName)

                Button("Todos los atajos en Ajustes…") {
                    dismiss()
                    appState.pendingSettingsTab = .hotkeys
                    appState.openSettings?()
                }
                .buttonStyle(.link)
                .padding(.top, 4)
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
