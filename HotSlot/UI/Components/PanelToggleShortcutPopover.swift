import KeyboardShortcuts
import SwiftUI

/// Editar el atajo global de abrir/cerrar el panel (por defecto ⌘⇧V).
struct PanelToggleShortcutPopover: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ShortcutRecorderPopoverLayout(width: 300, height: 220) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Este atajo funciona aunque el panel esté cerrado. Si otra app (p. ej. Cursor) usa el mismo, elegí otro o abrí el panel desde el ⌘ en la barra de menú.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ShortcutRecorderRow(title: "Abrir / cerrar panel", name: .togglePanel)

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
            if KeyboardShortcuts.getShortcut(for: .togglePanel) == nil {
                appState.showToast("Sin atajo de panel: usá el ⌘ arriba a la derecha o Ajustes → Atajos")
            }
        }
    }
}
