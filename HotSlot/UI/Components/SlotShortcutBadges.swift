import KeyboardShortcuts
import SwiftUI

/// Badges de pegar y guardar; un clic abre el editor (sin depender del peek del slot).
struct SlotShortcutBadges: View {
    let slotIndex: Int
    @Binding var isEditing: Bool
    @Binding var suppressPeek: Bool
    @State private var isHovering = false

    private var pasteName: KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.pasteSlotNames[slotIndex - 1]
    }

    private var copyName: KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.copyToSlotNames[slotIndex - 1]
    }

    var body: some View {
        HStack(spacing: 3) {
            badgeButton(name: pasteName, help: "Clic para cambiar atajo de pegar")
            badgeButton(name: copyName, help: "Clic para cambiar atajo de guardar")
        }
        .frame(width: HotSlotDesign.shortcutBadgeWidthCompact * 2 + 3, alignment: .trailing)
        .onHover { hovering in
            isHovering = hovering
            suppressPeek = hovering
        }
    }

    private func badgeButton(name: KeyboardShortcuts.Name, help: String) -> some View {
        Button {
            suppressPeek = true
            isEditing = true
        } label: {
            ShortcutBadge(name: name, compact: true, emphasized: isHovering)
        }
        .buttonStyle(.plain)
        .frame(width: HotSlotDesign.shortcutBadgeWidthCompact)
        .help(help)
    }
}
