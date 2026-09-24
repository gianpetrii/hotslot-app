import KeyboardShortcuts
import SwiftUI

struct SlotGridView: View {
    @Bindable var appState: AppState
    let panelController: PanelController

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Slots")

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(appState.slotStore.slots) { slot in
                    SlotCardView(
                        slot: slot,
                        onPaste: {
                            appState.pasteSlot(index: slot.index, panelController: panelController)
                        },
                        onSaveFromClipboard: {
                            if let content = appState.clipboardService.currentContent() {
                                appState.slotStore.saveContent(index: slot.index, content: content)
                                appState.showToast("Guardado en slot \(slot.index)")
                            }
                        },
                        onClear: {
                            appState.slotStore.clearSlot(index: slot.index)
                        }
                    )
                }
            }
            .padding(.horizontal, HotSlotDesign.horizontalPadding)
        }
    }
}

private struct SlotCardView: View {
    let slot: Slot
    let onPaste: () -> Void
    let onSaveFromClipboard: () -> Void
    let onClear: () -> Void
    @State private var isHovering = false

    private var hasContent: Bool { slot.content != nil }
    private var pasteShortcut: KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.pasteSlotNames[slot.index - 1]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                ShortcutBadge(name: pasteShortcut)
                    .scaleEffect(0.78)
            }
            .padding(.horizontal, 5)
            .padding(.top, 5)

            slotContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
        }
        .frame(height: 68)
        .background {
            RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(isHovering ? 0.07 : 0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                        .stroke(
                            hasContent
                                ? Color.accentColor.opacity(isHovering ? 0.35 : 0.2)
                                : Color.primary.opacity(0.12),
                            style: StrokeStyle(lineWidth: 0.5, dash: hasContent ? [] : [4, 3])
                        )
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous))
        .onTapGesture { onPaste() }
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .contextMenu {
            Button("Pegar") { onPaste() }
            Button("Guardar clipboard") { onSaveFromClipboard() }
            if hasContent {
                Button("Limpiar", role: .destructive) { onClear() }
            }
        }
        .help("Pegar slot \(slot.index)")
    }

    @ViewBuilder
    private var slotContent: some View {
        if let content = slot.content {
            switch content {
            case .image(let fileName):
                ClipThumbnailView(fileName: fileName, style: .slot)
            case .text(let string):
                Text(string.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 9, weight: .regular))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            Text("Vacío")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
