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
        GeometryReader { geometry in
            let gap = SlotsSpace.entreCards
            let columnWidth = (geometry.size.width - gap * 2) / 3
            let rowHeight = (geometry.size.height - gap) / 2

            HStack(spacing: gap) {
                slotCell(index: 1)
                    .frame(width: columnWidth, height: rowHeight * 2 + gap)

                VStack(spacing: gap) {
                    HStack(spacing: gap) {
                        slotCell(index: 2)
                            .frame(width: columnWidth, height: rowHeight)
                        slotCell(index: 3)
                            .frame(width: columnWidth, height: rowHeight)
                    }
                    HStack(spacing: gap) {
                        slotCell(index: 4)
                            .frame(width: columnWidth, height: rowHeight)
                        slotCell(index: 5)
                            .frame(width: columnWidth, height: rowHeight)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func slotCell(index: Int) -> some View {
        if let slot = appState.slotStore.slots.first(where: { $0.index == index }) {
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
            .opacity(slotSearchOpacity(for: slot))
        }
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

    private var pasteShortcut: KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.pasteSlotNames[slot.index - 1]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            cardChrome

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(SlotCardCopy.metaPrimary(for: slot))
                            .font(SlotsFont.etiqueta)
                        Text(SlotCardCopy.metaSecondary(for: slot))
                            .font(SlotsFont.etiqueta)
                    }
                    .foregroundStyle(metaForeground)

                    Spacer(minLength: 0)

                    Button {
                        suppressPeekForBadges = true
                        isEditingShortcuts = true
                    } label: {
                        SlotHandoffShortcutChip(name: pasteShortcut, emphasized: isHovering)
                    }
                    .buttonStyle(.plain)
                    .help("Clic para cambiar atajo de pegar")
                    .popover(isPresented: $isEditingShortcuts, arrowEdge: .leading) {
                        SlotShortcutEditorPopover(slotIndex: slot.index)
                    }
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 8) {
                    Text(SlotCardCopy.displayTitle(for: slot))
                        .font(SlotsFont.tituloCard)
                        .foregroundStyle(titleColor)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    if let swatch = colorSwatch {
                        Circle()
                            .fill(swatch)
                            .frame(width: 40, height: 40)
                    }
                }

                if !hasContent, let sub = SlotCardCopy.emptySubhint(slotIndex: slot.index) {
                    Text(sub)
                        .font(SlotsFont.textoUI)
                        .foregroundStyle(SlotsColor.textoSecundario)
                        .padding(.top, SlotsSpace.s)
                }
            }
            .padding(SlotsSpace.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous))
            .onTapGesture { onPaste() }

            if hasContent, isHovering {
                VStack {
                    HStack {
                        PanelGlyphButton(
                            systemImage: "xmark",
                            help: "Vaciar slot \(slot.index)",
                            size: HotSlotDesign.slotOverlayControlSize,
                            iconSize: HotSlotDesign.slotOverlayIconSize,
                            cornerRadius: HotSlotDesign.slotOverlayCornerRadius,
                            action: onClear
                        )
                        Spacer()
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var metaForeground: Color {
        if isDarkCard { return SlotsColor.textoSobreOscuro }
        if isImageContent, hasContent { return SlotsColor.textoTerciario }
        return SlotsColor.textoSecundario
    }

    private var titleColor: Color {
        if !hasContent {
            return slot.index == 5 ? SlotsColor.textoSecundario : SlotsColor.tinta
        }
        if isDarkCard || isImageContent { return .white }
        return SlotsColor.tinta
    }

    private var colorSwatch: Color? {
        guard case .text(let string) = slot.content else { return nil }
        return SlotCardCopy.colorFromHex(string.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var isDarkCard: Bool {
        guard case .text(let string) = slot.content else { return false }
        return SlotCardCopy.isHexColor(string.trimmingCharacters(in: .whitespacesAndNewlines))
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

    @ViewBuilder
    private var cardChrome: some View {
        ZStack {
            if isImageContent, case .image(let fileName) = slot.content {
                ClipThumbnailView(fileName: fileName, style: .slot)
                LinearGradient(
                    colors: [SlotsColor.naranja.opacity(0.35), Color.black.opacity(0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else if isDarkCard {
                RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                    .fill(SlotsColor.cardOscura)
            } else if hasContent {
                RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                    .fill(Color.white)
            } else {
                RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.28))
                    .overlay {
                        RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                            .strokeBorder(
                                Color.black.opacity(0.22),
                                style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                            )
                    }
            }
        }
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                    .strokeBorder(SlotsColor.naranja, lineWidth: 2)
            } else if isHovering, hasContent {
                RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                    .strokeBorder(SlotsColor.naranja.opacity(0.35), lineWidth: 1)
            }
        }
    }

    private var isImageContent: Bool {
        if case .image = slot.content { return true }
        return false
    }
}
