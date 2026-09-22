import KeyboardShortcuts

/// Nombres de atajos globales registrados con KeyboardShortcuts.
/// Defaults con ⌘⌃ (Control) para evitar conflicto con otros clipboard managers.
extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.v, modifiers: [.command, .control]))

    static let pasteSlot1 = Self("pasteSlot1", default: .init(.one, modifiers: [.command, .control]))
    static let pasteSlot2 = Self("pasteSlot2", default: .init(.two, modifiers: [.command, .control]))
    static let pasteSlot3 = Self("pasteSlot3", default: .init(.three, modifiers: [.command, .control]))
    static let pasteSlot4 = Self("pasteSlot4", default: .init(.four, modifiers: [.command, .control]))
    static let pasteSlot5 = Self("pasteSlot5", default: .init(.five, modifiers: [.command, .control]))

    static let copyToSlot1 = Self("copyToSlot1", default: .init(.one, modifiers: [.command, .option, .control]))
    static let copyToSlot2 = Self("copyToSlot2", default: .init(.two, modifiers: [.command, .option, .control]))
    static let copyToSlot3 = Self("copyToSlot3", default: .init(.three, modifiers: [.command, .option, .control]))
    static let copyToSlot4 = Self("copyToSlot4", default: .init(.four, modifiers: [.command, .option, .control]))
    static let copyToSlot5 = Self("copyToSlot5", default: .init(.five, modifiers: [.command, .option, .control]))

    static var pasteSlotNames: [KeyboardShortcuts.Name] {
        [.pasteSlot1, .pasteSlot2, .pasteSlot3, .pasteSlot4, .pasteSlot5]
    }

    static var copyToSlotNames: [KeyboardShortcuts.Name] {
        [.copyToSlot1, .copyToSlot2, .copyToSlot3, .copyToSlot4, .copyToSlot5]
    }

    static var allShortcutNames: [KeyboardShortcuts.Name] {
        [.togglePanel] + pasteSlotNames + copyToSlotNames
    }

    /// Restaura todos los atajos a los valores por defecto del código.
    static func resetAllToDefaults() {
        for name in allShortcutNames {
            KeyboardShortcuts.reset(name)
        }
    }
}
