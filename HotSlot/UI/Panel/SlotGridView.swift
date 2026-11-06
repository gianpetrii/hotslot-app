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
            .clipped()
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
                        .lineLimit(isHovering ? 8 : 4)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .modifier(SlotReadableText(onDark: prefersLightContent))
                        .animation(.easeOut(duration: 0.15), value: isHovering)
                } else if !hasContent {
                    Text(SlotCardCopy.emptyHint(slotIndex: slot.index))
                        .font(SlotsFont.textoUI)
                        .foregroundStyle(emptyHintColor)
                        .lineLimit(4)
                        .modifier(SlotReadableText(onDark: prefersLightContent))
                }

                titleRow
                    .frame(height: HotSlotDesign.slotTitleRowHeight, alignment: .bottomLeading)
            }
            .padding(SlotsSpace.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background { mixedBackgroundScrims }
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
        HStack(alignment: .center, spacing: 6) {
            if hasContent, isHovering {
                Button(action: onClear) {
                    SlotHeaderActionChip(systemImage: "xmark", foreground: headerChipInk, plate: headerChipPlate)
                }
                .buttonStyle(.plain)
                .help("Vaciar slot \(slot.index)")
                .transition(.opacity.combined(with: .scale(scale: 0.88)))
            }

            Text(SlotCardCopy.metaPrimary(for: slot))
                .font(SlotsFont.etiqueta)
                .foregroundStyle(metaForeground)
                .lineLimit(1)
                .modifier(SlotReadableText(onDark: prefersLightContent))

            Spacer(minLength: 4)

            Button {
                isEditingShortcuts = true
            } label: {
                SlotHandoffShortcutChip(name: visibleShortcut, ink: headerChipInk, plate: headerChipPlate)
            }
            .buttonStyle(.plain)
            .help(hasContent ? "Atajo pegar · clic para editar ambos" : "Atajo guardar · clic para editar ambos")
            .popover(isPresented: $isEditingShortcuts, arrowEdge: .leading) {
                SlotShortcutEditorPopover(slotIndex: slot.index)
            }
        }
    }

    /// Misma pastilla para la cruz y el atajo. Sobre fondos oscuros o imagen va clara; sobre cards claras, arena.
    private var headerChipPlate: Color {
        prefersLightContent ? Color.white.opacity(0.9) : SlotsColor.teclaFondo
    }

    private var headerChipInk: Color {
        SlotsColor.textoSecundario
    }

    @ViewBuilder
    private var titleRow: some View {
        HStack(alignment: .bottom, spacing: 6) {
            Group {
                if isEditingLabel {
                    TextField("Título", text: $labelDraft)
                        .textFieldStyle(.plain)
                        .font(SlotsFont.tituloCard)
                        .foregroundStyle(titleColor)
                        .focused($labelFieldFocused)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 4)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(SlotsColor.naranja.opacity(0.7), lineWidth: 1.5)
                        }
                        .onSubmit { commitLabelEdit() }
                        .onKeyPress(.escape) {
                            cancelLabelEdit()
                            return .handled
                        }
                } else {
                    Text(hasContent ? SlotCardCopy.slotLabelDisplay(for: slot) : SlotCardCopy.emptyPlaceholderTitle(for: slot))
                        .font(SlotsFont.tituloCard)
                        .foregroundStyle(titleColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .modifier(SlotReadableText(onDark: prefersLightContent))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "pencil")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(titleColor.opacity(0.75))
                .frame(width: 24, height: 24)
                .opacity(isTitleHovering && !isEditingLabel ? 1 : 0)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .contentShape(Rectangle())
        .onHover { isTitleHovering = $0 }
        .animation(.easeOut(duration: 0.14), value: isTitleHovering)
        .highPriorityGesture(
            TapGesture().onEnded {
                guard isTitleHovering, !isEditingLabel else { return }
                labelDraft = SlotCardCopy.slotLabelDisplay(for: slot)
                isEditingLabel = true
            }
        )
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
        if prefersLightContent { return .white }
        if !hasContent {
            return slot.index == 5 ? SlotsColor.textoSecundario : SlotsColor.tinta
        }
        return SlotsColor.tinta
    }

    private var emptyHintColor: Color {
        prefersLightContent ? Color.white.opacity(0.92) : SlotsColor.textoSecundario
    }

    /// Degradé e imagen: claro arriba, oscuro abajo. Un velo en cada punta para el texto blanco.
    @ViewBuilder
    private var mixedBackgroundScrims: some View {
        if needsMixedBackgroundScrims {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0.42), Color.black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 64)
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 140)
            }
            .allowsHitTesting(false)
        }
    }

    private var needsMixedBackgroundScrims: Bool {
        SlotsPalette.isBrandGradient(slot.cardBackgroundHex) || (isImageContent && hasContent)
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
        if isImageContent && hasContent { return true }
        if SlotsPalette.prefersLightContent(hexString: slot.cardBackgroundHex) { return true }
        // Color hex en el portapapeles: la card es oscura salvo que el usuario eligió un fondo claro.
        if isDarkCard, slot.cardBackgroundHex == nil { return true }
        return false
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
                GeometryReader { geo in
                    Image("DegradeNaranja")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                LinearGradient(
                    colors: [Color.black.opacity(0.22), Color.black.opacity(0.12), Color.black.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
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

private struct SlotReadableText: ViewModifier {
    var onDark: Bool

    func body(content: Content) -> some View {
        content.shadow(color: Color.black.opacity(onDark ? 0.55 : 0), radius: 5, y: 1)
    }
}

private struct SlotHeaderActionChip: View {
    let systemImage: String
    var foreground: Color
    var plate: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: HotSlotDesign.slotHeaderChipHeight, height: HotSlotDesign.slotHeaderChipHeight)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(plate)
            }
    }
}
