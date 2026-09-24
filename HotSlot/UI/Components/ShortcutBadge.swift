import KeyboardShortcuts
import SwiftUI

/// Badge compacto de atajo (estilo barra de acciones de macOS).
struct ShortcutBadge: View {
    let name: KeyboardShortcuts.Name

    var body: some View {
        if let shortcut = KeyboardShortcuts.Shortcut(name: name) {
            Text(shortcut.description)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                }
        }
    }
}
