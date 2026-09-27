import Carbon.HIToolbox
import KeyboardShortcuts

/// Conflictos de atajos: duplicados internos o reservados por macOS.
/// No cambia ningún atajo; solo informa para que el usuario grabe otro.
enum ShortcutConflict {
    struct Issue: Identifiable, Equatable {
        let name: KeyboardShortcuts.Name
        let title: String
        let shortcutDescription: String
        let duplicateTitles: [String]
        let takenBySystem: Bool

        var id: String { name.rawValue }

        var message: String {
            var parts: [String] = []
            if !duplicateTitles.isEmpty {
                parts.append("También está en \(duplicateTitles.joined(separator: ", ")).")
            }
            if takenBySystem {
                parts.append("macOS ya usa este atajo.")
            }
            return parts.joined(separator: " ")
        }
    }

    static func issues() -> [Issue] {
        let names = KeyboardShortcuts.Name.allShortcutNames
        var grouped: [KeyboardShortcuts.Shortcut: [KeyboardShortcuts.Name]] = [:]
        for name in names {
            guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else { continue }
            grouped[shortcut, default: []].append(name)
        }
        let system = symbolicSystemShortcuts()

        return names.compactMap { name in
            guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else { return nil }
            let peers = grouped[shortcut] ?? []
            let duplicates = peers
                .filter { $0.rawValue != name.rawValue }
                .map(\.settingsTitle)
            let takenBySystem = system.contains(shortcut)
            guard !duplicates.isEmpty || takenBySystem else { return nil }
            return Issue(
                name: name,
                title: name.settingsTitle,
                shortcutDescription: String(describing: shortcut),
                duplicateTitles: duplicates,
                takenBySystem: takenBySystem
            )
        }
    }

    /// Atajos de sistema (Mission Control, captura de pantalla, etc.).
    private static func symbolicSystemShortcuts() -> Set<KeyboardShortcuts.Shortcut> {
        var unmanaged: Unmanaged<CFArray>?
        guard
            CopySymbolicHotKeys(&unmanaged) == noErr,
            let raw = unmanaged?.takeRetainedValue() as? [[String: Any]]
        else {
            return []
        }

        return Set(raw.compactMap { entry in
            guard
                (entry[kHISymbolicHotKeyEnabled] as? Bool) == true,
                let carbonKeyCode = entry[kHISymbolicHotKeyCode] as? Int,
                let carbonModifiers = entry[kHISymbolicHotKeyModifiers] as? Int
            else {
                return nil
            }
            return KeyboardShortcuts.Shortcut(
                carbonKeyCode: carbonKeyCode,
                carbonModifiers: carbonModifiers
            )
        })
    }
}

extension KeyboardShortcuts.Name {
    var settingsTitle: String {
        switch rawValue {
        case "togglePanel":
            return "Abrir / cerrar panel"
        case "pasteSlot1": return "Pegar slot 1"
        case "pasteSlot2": return "Pegar slot 2"
        case "pasteSlot3": return "Pegar slot 3"
        case "pasteSlot4": return "Pegar slot 4"
        case "pasteSlot5": return "Pegar slot 5"
        case "copyToSlot1": return "Guardar slot 1"
        case "copyToSlot2": return "Guardar slot 2"
        case "copyToSlot3": return "Guardar slot 3"
        case "copyToSlot4": return "Guardar slot 4"
        case "copyToSlot5": return "Guardar slot 5"
        default:
            return rawValue
        }
    }
}
