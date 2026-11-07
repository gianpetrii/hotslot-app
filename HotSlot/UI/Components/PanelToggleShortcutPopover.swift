import KeyboardShortcuts
import SwiftUI

/// Editar el atajo global de abrir/cerrar el panel (por defecto ⌘⇧V).
struct PanelToggleShortcutPopover: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ShortcutRecorderPopoverLayout(width: 268) {
            VStack(alignment: .leading, spacing: SlotsSpace.s) {
                Text("Este atajo funciona con el panel cerrado. Si choca con otra app, elegí otro o usá el ícono de la barra de menú.")
                    .font(SlotsFont.etiqueta)
                    .foregroundStyle(SlotsColor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)

                ShortcutRecorderRow(title: "Panel", name: .togglePanel)

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
            if KeyboardShortcuts.getShortcut(for: .togglePanel) == nil {
                appState.showToast("Sin atajo de panel: usá el ícono de la barra de menú o Ajustes → Atajos")
            }
        }
    }
}
