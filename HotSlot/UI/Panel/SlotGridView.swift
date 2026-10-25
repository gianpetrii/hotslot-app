import AppKit
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
                                FeedbackSound.play(.saved)
                                appState.showToast("Guardado en slot \(slot.index)")
                            }
                        },
                        onSaveHistoryItem: { itemID in
                            guard let content = appState.historyStore.item(id: itemID)?.content else { return }
                            appState.slotStore.saveContent(index: slot.index, content: content)
                            FeedbackSound.play(.saved)
                            appState.showToast("Guardado en slot \(slot.index)")
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

private struct SlotCardView: View {
    let slot: Slot
    let onPaste: () -> Void
    let onSaveFromClipboard: () -> Void
    let onSaveHistoryItem: (UUID) -> Void
    let onClear: () -> Void
    let onSwapFrom: (Int) -> Void
    @State private var isHovering = false
    @State private var isDropTarget = false
    @State private var isPeeking = false
    @State private var isPeekHovered = false
    @State private var peekTask: Task<Void, Never>?
    @State private var isEditingShortcuts = false
    @State private var suppressPeekForBadges = false

    private var hasContent: Bool { slot.content != nil }

    var body: some View {
        ZStack(alignment: .top) {
            slotContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)
                .padding(contentPadding)
                .contentShape(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous))
                .onTapGesture { onPaste() }

            if isImageContent {
                LinearGradient(
                    colors: [Color.black.opacity(0.38), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 48)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
            }

            HStack(alignment: .top, spacing: 4) {
                if hasContent {
                    PanelGlyphButton(
                        systemImage: "xmark",
                        help: "Vaciar slot \(slot.index)",
                        size: HotSlotDesign.slotOverlayControlSize,
                        iconSize: HotSlotDesign.slotOverlayIconSize,
                        cornerRadius: HotSlotDesign.slotOverlayCornerRadius,
                        action: onClear
                    )
                    .opacity(isHovering ? 1 : 0)
                    .allowsHitTesting(isHovering)
                }
                Spacer(minLength: 0)
                SlotShortcutBadges(
                    slotIndex: slot.index,
                    isEditing: $isEditingShortcuts,
                    suppressPeek: $suppressPeekForBadges
                )
                .popover(isPresented: $isEditingShortcuts, arrowEdge: .leading) {
                    SlotShortcutEditorPopover(slotIndex: slot.index)
                }
            }
            .padding(6)
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
        .onHover { hovering in
            isHovering = hovering
            schedulePeek(hovering: hovering)
        }
        .popover(isPresented: $isPeeking, arrowEdge: .trailing) {
            if let content = slot.content {
                SlotPeekView(content: content)
                    .onHover { hovering in
                        isPeekHovered = hovering
                        schedulePeek(hovering: isHovering || hovering)
                    }
            }
        }
        .draggable(PanelDragPayload.slot(index: slot.index))
        .onDrop(of: [UTType.hotslotPanelDrag], isTargeted: $isDropTarget) { providers in
            Self.acceptDrop(providers) { payload in
                switch payload {
                case .slot(let source):
                    guard (1...SlotStore.slotCount).contains(source), source != slot.index else { return }
                    onSwapFrom(source)
                case .historyItem(let id):
                    onSaveHistoryItem(id)
                }
            }
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isDropTarget)
        .contextMenu {
            Button("Pegar") { onPaste() }
            Button("Guardar clipboard") { onSaveFromClipboard() }
            if hasContent {
                Button("Vaciar", role: .destructive) { onClear() }
            }
        }
        .help("Pegar slot \(slot.index). Arrastrá para intercambiar o soltá un clip del historial.")
        .onChange(of: isDropTarget) { _, targeted in
            if targeted {
                peekTask?.cancel()
                isPeeking = false
            }
        }
        .onChange(of: isEditingShortcuts) { _, editing in
            if editing {
                peekTask?.cancel()
                isPeeking = false
            }
        }
        .onDisappear {
            peekTask?.cancel()
            isPeeking = false
            isPeekHovered = false
        }
    }

    private func schedulePeek(hovering: Bool) {
        peekTask?.cancel()
        guard hasContent, !isDropTarget, !suppressPeekForBadges, !isEditingShortcuts else {
            isPeeking = false
            return
        }
        if hovering {
            peekTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(HotSlotDesign.hoverExpandDelay * 1_000_000_000))
                guard !Task.isCancelled, (isHovering || isPeekHovered), !isDropTarget else { return }
                isPeeking = true
            }
        } else {
            peekTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(HotSlotDesign.slotPeekHideDelay * 1_000_000_000))
                guard !Task.isCancelled, !isHovering, !isPeekHovered else { return }
                isPeeking = false
            }
        }
    }

    private static func acceptDrop(
        _ providers: [NSItemProvider],
        handle: @escaping (PanelDragPayload) -> Void
    ) -> Bool {
        let type = UTType.hotslotPanelDrag.identifier
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(type) }) else {
            return false
        }
        provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
            guard let data,
                  let payload = try? JSONDecoder().decode(PanelDragPayload.self, from: data) else { return }
            DispatchQueue.main.async {
                handle(payload)
            }
        }
        return true
    }

    private var fillOpacity: Double {
        if isDropTarget { return 0.12 }
        if isHovering { return 0.07 }
        return 0.04
    }

    private var isImageContent: Bool {
        if case .image = slot.content { return true }
        return false
    }

    private var contentAlignment: Alignment {
        if hasContent { return isImageContent ? .center : .topLeading }
        return .center
    }

    private var contentPadding: EdgeInsets {
        if isImageContent { return EdgeInsets() }
        if hasContent { return EdgeInsets(top: 28, leading: 8, bottom: 8, trailing: 8) }
        return EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
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
