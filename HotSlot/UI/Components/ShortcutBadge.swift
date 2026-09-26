import KeyboardShortcuts
import SwiftUI

/// Badge compacto de atajo (estilo barra de acciones de macOS).
struct ShortcutBadge: View {
    let name: KeyboardShortcuts.Name
    var compact: Bool = false
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let shortcut = KeyboardShortcuts.Shortcut(name: name) {
                Text(shortcut.description)
                    .font(.system(size: compact ? 10 : 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .frame(minHeight: compact ? HotSlotDesign.slotOverlayControlSize : nil)
                    .background {
                        RoundedRectangle(cornerRadius: compact ? HotSlotDesign.slotOverlayCornerRadius : 5, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    }
            }
        }
        .id("\(name.rawValue)-\(appState.shortcutEpoch)")
    }
}
