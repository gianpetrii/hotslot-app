import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers

struct SlotGridView: View {
    @Bindable var appState: AppState
    let panelController: PanelController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Slots")

            VStack(spacing: 8) {
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
                        },
                        onSwapFrom: { sourceIndex in
                            appState.slotStore.swapContents(from: sourceIndex, to: slot.index)
                        }
                    )
                    .frame(maxHeight: .infinity)
                }
            }
            .padding(.horizontal, HotSlotDesign.horizontalPadding)
            .padding(.bottom, 4)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct SlotDragToken: Codable, Transferable {
    let index: Int

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

private struct SlotCardView: View {
    let slot: Slot
    let onPaste: () -> Void
    let onSaveFromClipboard: () -> Void
    let onClear: () -> Void
    let onSwapFrom: (Int) -> Void
    @State private var isHovering = false
    @State private var isDropTarget = false

    private var hasContent: Bool { slot.content != nil }
    private var pasteShortcut: KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.pasteSlotNames[slot.index - 1]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                if hasContent {
                    PanelGlyphButton(
                        systemImage: "xmark",
                        help: "Vaciar slot \(slot.index)",
                        action: onClear
                    )
                    .opacity(isHovering ? 1 : 0)
                    .allowsHitTesting(isHovering)
                }
                Spacer(minLength: 0)
                ShortcutBadge(name: pasteShortcut)
                    .scaleEffect(0.84)
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)

            slotContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(fillOpacity))
                .overlay {
                    RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                        .stroke(
                            strokeColor,
                            style: StrokeStyle(lineWidth: isDropTarget ? 1.5 : 0.5, dash: hasContent ? [] : [4, 3])
                        )
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous))
        .onTapGesture { onPaste() }
        .onHover { isHovering = $0 }
        .draggable(SlotDragToken(index: slot.index))
        .dropDestination(for: SlotDragToken.self) { tokens, _ in
            guard let source = tokens.first?.index,
                  (1...SlotStore.slotCount).contains(source) else { return false }
            onSwapFrom(source)
            return true
        } isTargeted: { isDropTarget = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isDropTarget)
        .contextMenu {
            Button("Pegar") { onPaste() }
            Button("Guardar clipboard") { onSaveFromClipboard() }
            if hasContent {
                Button("Vaciar", role: .destructive) { onClear() }
            }
        }
        .help("Pegar slot \(slot.index). Arrastrá para intercambiar.")
    }

    private var fillOpacity: Double {
        if isDropTarget { return 0.12 }
        if isHovering { return 0.07 }
        return 0.04
    }

    private var strokeColor: Color {
        if isDropTarget { return Color.accentColor.opacity(0.7) }
        if hasContent { return Color.accentColor.opacity(isHovering ? 0.35 : 0.2) }
        return Color.primary.opacity(0.12)
    }

    @ViewBuilder
    private var slotContent: some View {
        if let content = slot.content {
            switch content {
            case .image(let fileName):
                ClipThumbnailView(fileName: fileName, style: .slot)
            case .text(let string):
                Text(string.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 11, weight: .regular))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            Text("Vacío")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
