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
                onUpdateLabel: { title in
                    appState.slotStore.updateLabel(index: slot.index, label: title)
                    UsageEventLog.shared.record("slot_renombrar", detail: "\(slot.index)")
                },
                onSetBackground: { hex in
                    appState.slotStore.updateCardBackground(index: slot.index, hex: hex)
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
    let onUpdateLabel: (String) -> Void
    let onSetBackground: (String?) -> Void
    let onReplaceFromClipboard: () -> Void
    let onMoveToLibrary: (UUID) -> Void
    @State private var isHovering = false
    @State private var isDropTarget = false
    @State private var isEditingShortcuts = false
    @State private var isEditingLabel = false
    @State private var isTitleHovering = false
    @State private var labelDraft = ""
    @FocusState private var labelFieldFocused: Bool

    private var hasContent: Bool { slot.content != nil }

    private var pasteShortcut: KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.pasteSlotNames[slot.index - 1]
    }

    private var copyShortcut: KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.copyToSlotNames[slot.index - 1]
    }

    private var visibleShortcut: KeyboardShortcuts.Name {
        hasContent ? pasteShortcut : copyShortcut
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            cardChrome
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            VStack(alignment: .leading, spacing: SlotsSpace.s) {
                headerRow

                Spacer(minLength: 0)

                if let preview = SlotCardCopy.contentBodyPreview(for: slot), !isImageContent {
                    Text(preview)
                        .font(SlotsFont.textoUI)
                        .foregroundStyle(bodyTextColor)
                        .lineLimit(isHovering ? 8 : 3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .animation(.easeOut(duration: 0.15), value: isHovering)
                } else if !hasContent {
                    Text(SlotCardCopy.emptyHint(slotIndex: slot.index))
                        .font(SlotsFont.textoUI)
                        .foregroundStyle(SlotsColor.textoSecundario)
                        .lineLimit(4)
                }

                titleRow
            }
            .padding(SlotsSpace.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous))
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                    .strokeBorder(SlotsColor.naranja, lineWidth: 2)
            } else if isHovering, hasContent {
                RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                    .strokeBorder(SlotsColor.naranja.opacity(0.35), lineWidth: 1)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous))
        .onTapGesture {
            if isEditingLabel {
                commitLabelEdit()
                return
            }
            onPaste()
        }
        .onHover { isHovering = $0 }
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
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isDropTarget)
        .contextMenu { slotContextMenu }
        .help("Clic para pegar · Arrastrá para intercambiar o soltá un clip del historial.")
        .onChange(of: isEditingLabel) { _, editing in
            if editing {
                labelDraft = SlotCardCopy.editableTitle(for: slot)
                DispatchQueue.main.async {
                    labelFieldFocused = true
                }
            }
        }
        .onChange(of: labelFieldFocused) { wasFocused, focused in
            if wasFocused, !focused, isEditingLabel {
                commitLabelEdit()
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            ZStack(alignment: .leading) {
                Text(SlotCardCopy.metaPrimary(for: slot))
                    .font(SlotsFont.etiqueta)
                    .foregroundStyle(metaForeground)
                    .offset(x: hasContent && isHovering ? 22 : 0)

                if hasContent, isHovering {
                    Button(action: onClear) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(clearButtonForeground)
                    }
                    .buttonStyle(.plain)
                    .help("Vaciar slot \(slot.index)")
                    .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isHovering)

            Spacer(minLength: 0)

            Button {
                isEditingShortcuts = true
            } label: {
                SlotHandoffShortcutChip(
                    name: visibleShortcut,
                    emphasized: isHovering,
                    onMediaBackground: isImageContent && hasContent
                )
            }
            .buttonStyle(.plain)
            .help(hasContent ? "Atajo pegar · clic para editar ambos" : "Atajo guardar · clic para editar ambos")
            .popover(isPresented: $isEditingShortcuts, arrowEdge: .leading) {
                SlotShortcutEditorPopover(slotIndex: slot.index)
            }
        }
    }

    private var clearButtonForeground: Color {
        prefersLightContent ? Color.white.opacity(0.92) : SlotsColor.textoSecundario
    }

    @ViewBuilder
    private var titleRow: some View {
        if isEditingLabel {
            TextField("Título", text: $labelDraft)
                .textFieldStyle(.plain)
                .font(SlotsFont.tituloCard)
                .foregroundStyle(titleColor)
                .focused($labelFieldFocused)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.85))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(SlotsColor.naranja.opacity(0.45), lineWidth: 1)
                        }
                }
                .onSubmit { commitLabelEdit() }
                .onKeyPress(.escape) {
                    cancelLabelEdit()
                    return .handled
                }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(hasContent ? SlotCardCopy.slotLabelDisplay(for: slot) : SlotCardCopy.emptyPlaceholderTitle(for: slot))
                    .font(SlotsFont.tituloCard)
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if isTitleHovering {
                    Image(systemName: "pencil")
                        .font(SlotsFont.tituloCard)
                        .foregroundStyle(SlotsColor.textoSecundario)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onHover { isTitleHovering = $0 }
            .highPriorityGesture(
                TapGesture().onEnded {
                    labelDraft = SlotCardCopy.slotLabelDisplay(for: slot)
                    isEditingLabel = true
                }
            )
        }
    }

    @ViewBuilder
    private var slotContextMenu: some View {
        Button("Renombrar…") {
            labelDraft = SlotCardCopy.slotLabelDisplay(for: slot)
            isEditingLabel = true
        }
        Menu("Color de fondo") {
            Button("Predeterminado (handoff)") { onSetBackground(nil) }
            Button("Degradé naranja (marca)") { onSetBackground(SlotsPalette.brandGradientAsset) }
            ForEach(SlotsPalette.slotBackgrounds.filter { $0.hex != 0xE2501D }, id: \.hex) { entry in
                Button(entry.name) {
                    onSetBackground(SlotsPalette.normalizedHex(entry.hex))
                }
            }
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

    private func commitLabelEdit() {
        let trimmed = labelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelLabelEdit()
            return
        }
        onUpdateLabel(trimmed)
        isEditingLabel = false
        labelFieldFocused = false
    }

    private func cancelLabelEdit() {
        isEditingLabel = false
        labelFieldFocused = false
    }

    private var bodyTextColor: Color {
        prefersLightContent ? .white : SlotsColor.tinta
    }

    private var metaForeground: Color {
        if prefersLightContent { return Color.white.opacity(0.85) }
        return SlotsColor.textoSecundario
    }

    private var titleColor: Color {
        if !hasContent {
            return slot.index == 5 ? SlotsColor.textoSecundario : SlotsColor.tinta
        }
        if prefersLightContent { return .white }
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

    private var prefersLightContent: Bool {
        isDarkCard || (isImageContent && hasContent) || isDarkCustomBackground
    }

    private var isDarkCustomBackground: Bool {
        guard let hex = slot.cardBackgroundHex?.uppercased() else { return false }
        return hex.contains("1C1C1C") || hex.contains("111111")
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
            if SlotsPalette.isBrandGradient(slot.cardBackgroundHex) {
                Image("DegradeNaranja")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isImageContent, case .image(let fileName) = slot.content {
                ClipThumbnailView(fileName: fileName, style: .slot)
                LinearGradient(
                    colors: [Color.black.opacity(0.12), Color.black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else if let custom = SlotsPalette.color(hexString: slot.cardBackgroundHex) {
                RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                    .fill(custom)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous))
    }

    private var isImageContent: Bool {
        if case .image = slot.content { return true }
        return false
    }
}
