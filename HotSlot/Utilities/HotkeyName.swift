import KeyboardShortcuts

/// Nombres de atajos globales registrados con KeyboardShortcuts.
extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.v, modifiers: [.command, .shift]))

    static let pasteSlot1 = Self("pasteSlot1", default: .init(.a, modifiers: [.command, .shift]))
    static let pasteSlot2 = Self("pasteSlot2", default: .init(.s, modifiers: [.command, .shift]))
    static let pasteSlot3 = Self("pasteSlot3", default: .init(.d, modifiers: [.command, .shift]))
    static let pasteSlot4 = Self("pasteSlot4", default: .init(.q, modifiers: [.command, .shift]))
    static let pasteSlot5 = Self("pasteSlot5", default: .init(.w, modifiers: [.command, .shift]))

    static let copyToSlot1 = Self("copyToSlot1", default: .init(.a, modifiers: [.command, .control]))
    static let copyToSlot2 = Self("copyToSlot2", default: .init(.s, modifiers: [.command, .control]))
    static let copyToSlot3 = Self("copyToSlot3", default: .init(.d, modifiers: [.command, .control]))
    static let copyToSlot4 = Self("copyToSlot4", default: .init(.q, modifiers: [.command, .control]))
    static let copyToSlot5 = Self("copyToSlot5", default: .init(.w, modifiers: [.command, .control]))

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

    /// Defaults viejos, para migrar solo si el usuario no grabó otros.
    static var legacyNumericPasteDefaults: [KeyboardShortcuts.Shortcut] {
        [
            .init(.one, modifiers: [.command, .shift]),
            .init(.two, modifiers: [.command, .shift]),
            .init(.three, modifiers: [.command, .shift]),
            .init(.four, modifiers: [.command, .shift]),
            .init(.five, modifiers: [.command, .shift]),
        ]
    }

    static var legacyNumericCopyDefaults: [KeyboardShortcuts.Shortcut] {
        [
            .init(.one, modifiers: [.command, .option]),
            .init(.two, modifiers: [.command, .option]),
            .init(.three, modifiers: [.command, .option]),
            .init(.four, modifiers: [.command, .option]),
            .init(.five, modifiers: [.command, .option]),
        ]
    }

    static var legacyOptionLetterCopyDefaults: [KeyboardShortcuts.Shortcut] {
        [
            .init(.a, modifiers: [.command, .option]),
            .init(.s, modifiers: [.command, .option]),
            .init(.d, modifiers: [.command, .option]),
            .init(.q, modifiers: [.command, .option]),
            .init(.w, modifiers: [.command, .option]),
        ]
    }
}
