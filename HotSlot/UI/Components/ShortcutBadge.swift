import KeyboardShortcuts
import SwiftUI

/// Badge compacto de atajo (estilo barra de acciones de macOS).
struct ShortcutBadge: View {
    let name: KeyboardShortcuts.Name
    var compact: Bool = false
    var emphasized: Bool = false
    @Environment(AppState.self) private var appState

    private var badgeWidth: CGFloat {
        compact ? HotSlotDesign.shortcutBadgeWidthCompact : HotSlotDesign.shortcutBadgeWidthRegular
    }

    var body: some View {
        let _ = appState.shortcutEpoch
        let label = KeyboardShortcuts.Shortcut(name: name)?.description ?? "—"

        Text(label)
            .font(.system(size: compact ? 10 : 11, weight: .medium))
            .foregroundStyle(
                label == "—"
                    ? Color.secondary.opacity(0.7)
                    : (emphasized ? Color.primary : Color.secondary)
            )
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(width: badgeWidth - 12, alignment: .center)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(width: badgeWidth, height: compact ? HotSlotDesign.slotOverlayControlSize : nil, alignment: .center)
            .background {
                RoundedRectangle(cornerRadius: compact ? HotSlotDesign.slotOverlayCornerRadius : 5, style: .continuous)
                    .fill(Color.primary.opacity(emphasized ? 0.14 : 0.08))
                    .overlay {
                        if emphasized {
                            RoundedRectangle(cornerRadius: compact ? HotSlotDesign.slotOverlayCornerRadius : 5, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 0.5)
                        }
                    }
            }
    }
}
