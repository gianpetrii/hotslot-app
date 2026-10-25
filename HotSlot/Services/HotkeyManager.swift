import Foundation
import KeyboardShortcuts

/// Escucha atajos globales. Los handlers se instalan una sola vez; `reloadFromStorage` solo vuelve a registrar Carbon.
@MainActor
final class HotkeyManager {
    var onTogglePanel: (() -> Void)?
    var onPasteSlot: ((Int) -> Void)?
    var onCopyToSlot: ((Int) -> Void)?

    private var handlersInstalled = false

    /// Vuelve a leer UserDefaults y registra atajos en Carbon (tras grabar o cerrar Ajustes / popovers).
    func reloadFromStorage() {
        KeyboardShortcuts.enable(KeyboardShortcuts.Name.allShortcutNames)
    }

    func registerAll() {
        installHandlersIfNeeded()
        reloadFromStorage()
    }

    func applyStoredShortcuts() {
        reloadFromStorage()
    }

    private func installHandlersIfNeeded() {
        guard !handlersInstalled else { return }
        handlersInstalled = true

        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in
            Task { @MainActor in
                self?.onTogglePanel?()
            }
        }

        for (offset, name) in KeyboardShortcuts.Name.pasteSlotNames.enumerated() {
            let index = offset + 1
            KeyboardShortcuts.onKeyUp(for: name) { [weak self] in
                Task { @MainActor in
                    self?.onPasteSlot?(index)
                }
            }
        }

        for (offset, name) in KeyboardShortcuts.Name.copyToSlotNames.enumerated() {
            let index = offset + 1
            KeyboardShortcuts.onKeyUp(for: name) { [weak self] in
                Task { @MainActor in
                    self?.onCopyToSlot?(index)
                }
            }
        }
    }
}
