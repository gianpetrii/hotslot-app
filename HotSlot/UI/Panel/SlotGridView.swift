import AppKit
import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers

struct SlotGridView: View {
    @Bindable var appState: AppState
    let panelController: PanelController
    var searchText: String = ""

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Slots")

            VStack(spacing: 8) {
                ForEach(appState.slotStore.slots) { slot in
                    SlotCardView(
                        slot: slot,
                        otherLibraries: appState.libraryWorkspace.workspace.libraries
                            .filter { $0.id != appState.libraryWorkspace.workspace.activeLibraryId }
                            .sorted { $0.order < $1.order },
                        onPaste: {
                            appState.pasteSlot(index: slot.index, panelController: panelController)
                        },
                        onSaveFromClipboard: {
                            if let content = appState.clipboardService.currentContent() {
                                appState.saveToSlot(index: slot.index, content: content)
                            }
                        },
                        onSaveHistoryItem: { itemID in
                            guard let content = appState.historyStore.item(id: itemID)?.content else { return }
                            appState.saveToSlot(index: slot.index, content: content)
                        },
                        onClear: {
                            appState.slotStore.clearSlot(index: slot.index)
                        },
                        onSwapFrom: { sourceIndex in
                            appState.slotStore.swapContents(from: sourceIndex, to: slot.index)
                        },
                        onRename: { title in
                            appState.slotStore.updateLabel(index: slot.index, label: title)
                        },
                        onReplaceFromClipboard: {
                            appState.replaceSlotFromClipboard(index: slot.index)
                        },
                        onMoveToLibrary: { libraryId in
                            appState.moveSlotToLibrary(slotIndex: slot.index, libraryId: libraryId)
                        }
                    )
                    .frame(maxHeight: .infinity)
                    .opacity(slotSearchOpacity(for: slot))
                }
            }
            .padding(.horizontal, HotSlotDesign.horizontalPadding)
            .padding(.bottom, 4)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func slotSearchOpacity(for slot: Slot) -> Double {
        guard isSearching else { return 1 }
        return slot.matchesSearch(searchText) ? 1 : 0.3
    }
}

private struct SlotCardView: View {
    let slot: Slot
    let otherLibraries: [Library]
    let onPaste: () -> Void
    let onSaveFromClipboard: () -> Void
    let onSaveHistoryItem: (UUID) -> Void
    let onClear: () -> Void
    let onSwapFrom: (Int) -> Void
    let onRename: (String) -> Void
    let onReplaceFromClipboard: () -> Void
    let onMoveToLibrary: (UUID) -> Void
    @State private var isHovering = false
    @State private var isDropTarget = false
    @State private var isPeeking = false
    @State private var isPeekHovered = false
    @State private var peekTask: Task<Void, Never>?
    @State private var isEditingShortcuts = false
    @State private var suppressPeekForBadges = false
    @State private var showRenameAlert = false
    @State private var renameDraft = ""

    private var hasContent: Bool { slot.content != nil }

    var body: some View {
        ZStack(alignment: .topLeading) {
            cardChrome

            VStack(alignment: .leading, spacing: 6) {
                Text(SlotCardCopy.metaLine(for: slot))
                    .font(SlotsFont.etiqueta)
                    .foregroundStyle(isImageContent && hasContent ? Color.white.opacity(0.85) : SlotsColor.textoSecundario)
                    .padding(.top, hasContent ? 36 : 12)
                    .padding(.horizontal, 12)

                Text(SlotCardCopy.displayTitle(for: slot))
                    .font(SlotsFont.tituloCard)
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                    .padding(.horizontal, 12)

                if hasContent, !isImageContent {
                    slotBodyPreview
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                } else if !hasContent {
                    Text(SlotCardCopy.emptyHint(slotIndex: slot.index))
                        .font(SlotsFont.textoUI)
                        .foregroundStyle(SlotsColor.textoSecundario)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 12)
                } else {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous))
            .onTapGesture { onPaste() }

            overlayControls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            Button("Renombrar…") {
                renameDraft = slot.label
                showRenameAlert = true
            }
            Button("Reemplazar con el portapapeles") {
                onReplaceFromClipboard()
            }
            if !otherLibraries.isEmpty {
                Menu("Mover a…") {
                    ForEach(otherLibraries) { library in
                        Button(library.name) {
                            onMoveToLibrary(library.id)
                        }
                    }
                }
            }
            Divider()
            Button("Pegar") { onPaste() }
            if hasContent {
                Button("Vaciar slot", role: .destructive) { onClear() }
            }
        }
        .alert("Renombrar slot \(slot.index)", isPresented: $showRenameAlert) {
            TextField("Título", text: $renameDraft)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") {
                onRename(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines))
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

    private var titleColor: Color {
        if !hasContent { return SlotsColor.tinta }
        if isImageContent { return .white }
        return SlotsColor.tinta
    }

    @ViewBuilder
    private var cardChrome: some View {
        ZStack {
            if isImageContent, case .image(let fileName) = slot.content {
                ClipThumbnailView(fileName: fileName, style: .slot)
                LinearGradient(
                    colors: [Color.black.opacity(0.55), Color.black.opacity(0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                    .fill(hasContent ? Color.white : SlotsColor.papel)
                    .overlay {
                        RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                            .stroke(
                                strokeColor,
                                style: StrokeStyle(lineWidth: isDropTarget ? 2 : 1, dash: hasContent ? [] : [6, 4])
                            )
                    }
            }
        }
    }

    private var overlayControls: some View {
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

    @ViewBuilder
    private var slotBodyPreview: some View {
        if case .text(let string) = slot.content {
            Text(string.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(SlotsFont.textoUI)
                .lineLimit(3)
                .foregroundStyle(SlotsColor.textoTerciario)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var isImageContent: Bool {
        if case .image = slot.content { return true }
        return false
    }

    private var strokeColor: Color {
        if isDropTarget { return SlotsColor.naranja }
        if isHovering, hasContent { return SlotsColor.naranja.opacity(0.45) }
        if hasContent { return SlotsColor.linea }
        return SlotsColor.linea
    }
}
