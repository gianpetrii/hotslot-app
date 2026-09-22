import Foundation
import KeyboardShortcuts

/// Registra y escucha atajos globales.
@MainActor
final class HotkeyManager {
    var onTogglePanel: (() -> Void)?
    var onPasteSlot: ((Int) -> Void)?
    var onCopyToSlot: ((Int) -> Void)?

    func registerAll() {
        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in
            self?.onTogglePanel?()
        }

        for (offset, name) in KeyboardShortcuts.Name.pasteSlotNames.enumerated() {
            let index = offset + 1
            KeyboardShortcuts.onKeyUp(for: name) { [weak self] in
                self?.onPasteSlot?(index)
            }
        }

        for (offset, name) in KeyboardShortcuts.Name.copyToSlotNames.enumerated() {
            let index = offset + 1
            KeyboardShortcuts.onKeyUp(for: name) { [weak self] in
                self?.onCopyToSlot?(index)
            }
        }
    }
}
