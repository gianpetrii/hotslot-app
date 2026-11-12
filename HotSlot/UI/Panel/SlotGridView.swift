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

    /// Margen para que la sombra del hover no se corte en el borde de la zona con scroll.
    private let shadowSide: CGFloat = 12
    private let shadowVertical: CGFloat = 8

    private struct ScrollMetrics: Equatable {
        var offset: CGFloat = 0
        var content: CGFloat = 0
        var viewport: CGFloat = 0
    }

    @State private var scrollMetrics = ScrollMetrics()
    @State private var scrollPosition = ScrollPosition()
    @State private var gridFrame: CGRect = .zero

    /// Franja (en pt) donde, mientras arrastrás, la grilla se desplaza sola.
    private static let autoScrollZone: CGFloat = 56

    /// Mientras hay un clic sostenido (arrastre) cerca del borde de la grilla, la desplaza.
    private func autoScrollWhileDragging() {
        guard NSEvent.pressedMouseButtons & 1 != 0, appState.isPanelVisible, gridFrame.height > 0,
              let window = NSApp.windows.first(where: { $0.isVisible && String(describing: type(of: $0)) == "FloatingPanel" }),
              let contentHeight = window.contentView?.bounds.height else { return }
        let point = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        guard point.x >= gridFrame.minX, point.x <= gridFrame.maxX else { return }
        let y = contentHeight - point.y
        let zone = Self.autoScrollZone
        var delta: CGFloat = 0
        if y > gridFrame.maxY - zone, y < gridFrame.maxY + zone {
            delta = min(1, (y - (gridFrame.maxY - zone)) / zone) * 14
        } else if y < gridFrame.minY + zone, y > gridFrame.minY - zone {
            delta = -min(1, ((gridFrame.minY + zone) - y) / zone) * 14
        }
        guard delta != 0 else { return }
        let maxOffset = max(0, scrollMetrics.content - scrollMetrics.viewport)
        let target = min(max(scrollMetrics.offset + delta, 0), maxOffset)
        guard target != scrollMetrics.offset else { return }
        scrollPosition.scrollTo(y: target)
    }

    var body: some View {
        GeometryReader { geometry in
            let gap = SlotsSpace.entreCards
            let columnWidth = (geometry.size.width - gap * 2) / 3
            // Las filas tienen alto fijo: con 5 slots la grilla llena justo la vista.
            let rowHeight = (geometry.size.height - gap) / 2
            let extraSlots = appState.slotStore.allSlots.filter { $0.index > SlotStore.slotCount }

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(spacing: gap) {
                        mosaic(columnWidth: columnWidth, rowHeight: rowHeight, gap: gap)
                            .frame(height: rowHeight * 2 + gap)
                            .id(Self.topAnchor)

                        if !extraSlots.isEmpty {
                            noShortcutDivider
                        }

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.fixed(columnWidth), spacing: gap), count: 3),
                            spacing: gap
                        ) {
                            ForEach(extraSlots) { slot in
                                slotCell(index: slot.index)
                                    .frame(height: rowHeight)
                                    .id(slot.index)
                            }
                            NewSlotCardView(appState: appState)
                            .frame(height: rowHeight)
                            .id(Self.newSlotAnchor)
                        }
                    }
                    .padding(.horizontal, shadowSide)
                    .padding(.vertical, shadowVertical)
                }
                .scrollIndicators(.hidden)
                .scrollPosition($scrollPosition)
                .onReceive(Timer.publish(every: 1.0 / 40.0, on: .main, in: .common).autoconnect()) { _ in
                    autoScrollWhileDragging()
                }
                .onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
                    ScrollMetrics(
                        offset: geometry.contentOffset.y,
                        content: geometry.contentSize.height,
                        viewport: geometry.containerSize.height
                    )
                } action: { _, metrics in
                    scrollMetrics = metrics
                }
                // El recorte es más ancho que la grilla; el contenido vuelve a su lugar con el padding de adentro.
                .padding(.horizontal, -shadowSide)
                .padding(.vertical, -shadowVertical)
                .overlay(alignment: .topTrailing) { scrollThumb }
                .onChange(of: appState.isPanelVisible) { _, visible in
                    if visible { proxy.scrollTo(Self.topAnchor, anchor: .top) }
                }
                .onChange(of: appState.slotScrollTarget) { _, target in
                    guard let target else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if target.index <= SlotStore.slotCount {
                                proxy.scrollTo(Self.topAnchor, anchor: .top)
                            } else {
                                proxy.scrollTo(target.index, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { gridFrame = proxy.frame(in: .global) }
                    .onChange(of: proxy.frame(in: .global)) { _, frame in gridFrame = frame }
            }
        }
    }

    /// Barra de scroll fina (5 pt), visible solo mientras hay más contenido.
    @ViewBuilder
    private var scrollThumb: some View {
        let metrics = scrollMetrics
        let scrollable = metrics.content - metrics.viewport
        if scrollable > 1, metrics.viewport > 0 {
            let thumbHeight = max(28, metrics.viewport * metrics.viewport / metrics.content)
            let progress = min(max(metrics.offset / scrollable, 0), 1)
            Capsule()
                .fill(SlotsColor.tinta.opacity(0.28))
                .frame(width: 5, height: thumbHeight)
                .offset(y: progress * (metrics.viewport - thumbHeight))
                .padding(.trailing, 3)
                .allowsHitTesting(false)
        }
    }

    private static let newSlotAnchor = "new-slot"
    private static let topAnchor = "grid-top"

    /// Los 5 slots con atajo: el 1 alto a la izquierda y los otros cuatro en 2x2.
    private func mosaic(columnWidth: CGFloat, rowHeight: CGFloat, gap: CGFloat) -> some View {
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

    private var noShortcutDivider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(SlotsColor.tinta.opacity(0.14)).frame(height: 1)
            Text("Sin atajo · arrastrá un slot arriba de esta línea para darle uno")
                .font(.system(size: 12))
                .foregroundStyle(SlotsColor.textoSecundario)
                .fixedSize()
            Rectangle().fill(SlotsColor.tinta.opacity(0.14)).frame(height: 1)
        }
        .frame(height: 24)
    }

    @ViewBuilder
    private func slotCell(index: Int) -> some View {
        if let slot = appState.slotStore.allSlots.first(where: { $0.index == index }) {
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
                onSaveFile: { url in
                    appState.saveToSlot(index: slot.index, content: .fileReference(url: url))
                },
                onSaveHistoryItem: { itemID in
                    guard let content = appState.historyStore.item(id: itemID)?.content else { return }
                    appState.saveToSlot(index: slot.index, content: content)
                },
                onClear: {
                    appState.slotStore.clearSlot(index: slot.index)
                },
                onSwapFrom: { sourceIndex in
                    appState.reorderSlot(from: sourceIndex, to: slot.index)
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
                },
                onDiscardNew: {
                    appState.discardPendingNewSlot()
                }
            )
            .opacity(slotSearchOpacity(for: slot))
            .modifier(SwapFlashModifier(isSwapped: appState.swapHighlight?.indices.contains(index) == true))
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
    let onSaveFile: (URL) -> Void
    let onSaveHistoryItem: (UUID) -> Void
    let onClear: () -> Void
    let onSwapFrom: (Int) -> Void
    let onUpdateLabel: (String) -> Void
    let onSetBackground: (String?) -> Void
    let onReplaceFromClipboard: () -> Void
    let onMoveToLibrary: (UUID) -> Void
    let onDiscardNew: () -> Void
    @State private var didStartNewSlotEdit = false
    @State private var isHovering = false
    @State private var isDropTarget = false
    @State private var isEditingShortcuts = false
    @State private var isEditingLabel = false
    @State private var labelDraft = ""
    @State private var copyFlash = false
    @FocusState private var labelFieldFocused: Bool
    @Environment(AppState.self) private var appState

    private var hasContent: Bool { slot.content != nil }

    /// Slot que acaba de crearse con «Nuevo slot» y todavía no tiene contenido.
    private var isNewlyCreated: Bool {
        appState.pendingNewSlot == slot.index && !hasContent
    }

    private func startNewSlotEditIfNeeded() {
        guard isNewlyCreated, !didStartNewSlotEdit, !isEditingLabel else { return }
        didStartNewSlotEdit = true
        beginLabelEdit()
    }

    /// Solo los primeros 5 slots tienen atajo, por posición.
    private var visibleShortcut: KeyboardShortcuts.Name? {
        guard (1...SlotStore.slotCount).contains(slot.index) else { return nil }
        return hasContent
            ? KeyboardShortcuts.Name.pasteSlotNames[slot.index - 1]
            : KeyboardShortcuts.Name.copyToSlotNames[slot.index - 1]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            cardChrome
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            VStack(alignment: .leading, spacing: SlotsSpace.s) {
                headerRow

                Spacer(minLength: 0)

                if case .file = slot.content, let content = slot.content {
                    SlotFileBlock(
                        content: content,
                        iconSize: 52,
                        ink: bodyTextColor,
                        secondaryInk: metaForeground
                    )
                    .modifier(SlotReadableText(onDark: prefersLightContent))
                } else if let preview = SlotCardCopy.contentBodyPreview(for: slot), !isImageContent {
                    Text(preview)
                        .font(SlotsFont.textoUI)
                        .foregroundStyle(bodyTextColor)
                        .lineLimit(isHovering ? 8 : 4)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .modifier(SlotReadableText(onDark: prefersLightContent))
                        .animation(.easeOut(duration: 0.15), value: isHovering)
                } else if !hasContent {
                    Text(isNewlyCreated ? "Soltá algo acá o pegá con ⌘V" : SlotCardCopy.emptyHint(slotIndex: slot.index))
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
        .animation(.easeInOut(duration: 0.28), value: chromePhase)
        .padding(2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous))
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                    .strokeBorder(SlotsColor.naranja, lineWidth: 2)
            }
        }
        .overlay {
            cardChrome
                .opacity(copyFlash ? 1 : 0)
                .allowsHitTesting(false)
        }
        .slotsHoverLift(isHovering && hasContent && !copyFlash, scales: true)
        .contentShape(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous))
        .onTapGesture {
            if isEditingLabel {
                commitLabelEdit()
                return
            }
            confirmCopy()
        }
        .onHover { isHovering = $0 }
        .draggable(PanelDragPayload.slot(index: slot.index, libraryId: appState.libraryWorkspace.workspace.activeLibraryId))
        .onDrop(of: [UTType.hotslotPanelDrag, UTType.fileURL], isTargeted: $isDropTarget) { providers in
            // Archivo o carpeta arrastrado desde Finder u otra app.
            if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url, url.isFileURL else { return }
                    DispatchQueue.main.async { onSaveFile(url) }
                }
                return true
            }
            return Self.acceptDrop(providers) { payload in
                switch payload {
                case .slot(let source, let sourceLibrary):
                    guard source >= 1 else { return }
                    let activeLibrary = appState.libraryWorkspace.workspace.activeLibraryId
                    if sourceLibrary == activeLibrary {
                        guard source != slot.index else { return }
                        onSwapFrom(source)
                    } else {
                        // Venía de otra biblioteca (el panel cambió mientras arrastrabas).
                        appState.moveSlotToLibrary(
                            slotIndex: source, fromLibraryId: sourceLibrary,
                            libraryId: activeLibrary, toOrder: slot.index
                        )
                    }
                case .historyItem(let id):
                    onSaveHistoryItem(id)
                }
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isDropTarget)
        .contextMenu { slotContextMenu }
        .help(clickHelp)
        .onChange(of: isEditingLabel) { _, editing in
            if editing {
                labelDraft = SlotCardCopy.editingTitle(for: slot)
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
        .onChange(of: appState.isPanelVisible) { _, visible in
            guard visible, copyFlash else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { copyFlash = false }
        }
        .onChange(of: appState.inlineEditSession) { _, _ in
            guard isEditingLabel else { return }
            if appState.inlineEditShouldSave {
                commitLabelEdit()
            } else {
                cancelLabelEdit(discardIfNew: true)
            }
        }
        .onAppear { startNewSlotEditIfNeeded() }
        .onChange(of: appState.pendingNewSlot) { _, _ in startNewSlotEditIfNeeded() }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 6) {
            if hasContent, isHovering {
                Button(action: onClear) {
                    SlotHeaderActionChip(systemImage: "xmark", foreground: headerChipInk, plate: headerChipPlate)
                }
                .buttonStyle(.plain)
                .help("Vaciar slot")
                .transition(.opacity.combined(with: .scale(scale: 0.88)))
            }

            Text(SlotCardCopy.metaPrimary(for: slot))
                .font(SlotsFont.etiqueta)
                .foregroundStyle(metaForeground)
                .lineLimit(1)
                .modifier(SlotReadableText(onDark: prefersLightContent))

            Spacer(minLength: 4)

            if let visibleShortcut {
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
            } else {
                Text("Sin atajo")
                    .font(SlotsFont.etiqueta)
                    .foregroundStyle(headerChipInk.opacity(0.8))
                    .padding(.horizontal, 5)
                    .frame(minHeight: HotSlotDesign.slotHeaderChipHeight)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(headerChipPlate)
                    }
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

    private func confirmCopy() {
        guard hasContent else {
            onPaste()
            return
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { copyFlash = true }
        onPaste()
    }

    private var clickHelp: String {
        let action = appState.settings.clickItemAction == .copyToClipboard
            ? "Clic para copiar (⌘V para pegar)"
            : "Clic para pegar"
        return "\(action) · Arrastrá para intercambiar o soltá un clip del historial."
    }

    @ViewBuilder
    private var titleRow: some View {
        HStack(alignment: .bottom, spacing: 6) {
            Group {
                if isEditingLabel {
                    TextField(isNewlyCreated ? "Nombre del slot" : "Título", text: $labelDraft)
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
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    Text(SlotCardCopy.visibleCardTitle(for: slot))
                        .font(SlotsFont.tituloCard)
                        .foregroundStyle(titleColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .modifier(SlotReadableText(onDark: prefersLightContent))
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .contentShape(Rectangle())
        .animation(HotSlotDesign.titleEditAnimation, value: isEditingLabel)
    }

    @ViewBuilder
    private var slotContextMenu: some View {
        Button("Renombrar…") {
            beginLabelEdit()
        }
        Menu("Color de fondo") {
            Button { onSetBackground(nil) } label: {
                Label { Text("Predeterminado (Piedra)") } icon: { Image(nsImage: Self.colorDot(0xE6E3DE)) }
            }
            Button { onSetBackground(SlotsPalette.brandGradientAsset) } label: {
                Label { Text("Degradé naranja (marca)") } icon: { Image(nsImage: Self.colorDot(0xE2501D)) }
            }
            ForEach(SlotsPalette.slotBackgrounds, id: \.hex) { entry in
                Button {
                    onSetBackground(SlotsPalette.normalizedHex(entry.hex))
                } label: {
                    Label { Text(entry.name) } icon: { Image(nsImage: Self.colorDot(entry.hex)) }
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
        Button(appState.settings.clickItemAction == .copyToClipboard ? "Copiar" : "Pegar") { confirmCopy() }
        if hasContent {
            Button("Vaciar slot", role: .destructive) { onClear() }
        }
    }

    /// Círculo de color para el menú de fondos.
    private static func colorDot(_ hex: UInt32) -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size, flipped: false) { rect in
            let color = NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
            color.setFill()
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            path.fill()
            NSColor.black.withAlphaComponent(0.2).setStroke()
            path.lineWidth = 0.5
            path.stroke()
            return true
        }
        image.isTemplate = false
        return image
    }

    private func beginLabelEdit() {
        if appState.pendingNewSlot != slot.index { appState.pendingNewSlot = nil }
        appState.beginInlineEdit()
        labelDraft = SlotCardCopy.editingTitle(for: slot)
        withAnimation(HotSlotDesign.titleEditAnimation) {
            isEditingLabel = true
        }
    }

    private func commitLabelEdit() {
        guard isEditingLabel else { return }
        let trimmed = labelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelLabelEdit()
            return
        }
        onUpdateLabel(trimmed)
        withAnimation(HotSlotDesign.titleEditAnimation) {
            isEditingLabel = false
        }
        labelFieldFocused = false
        appState.isInlineEditing = false
    }

    /// `discardIfNew`: Esc sobre un slot nuevo sin nombre ni contenido lo descarta.
    private func cancelLabelEdit(discardIfNew: Bool = false) {
        guard isEditingLabel else { return }
        let discards = discardIfNew && isNewlyCreated && !SlotCardCopy.hasCustomLabel(slot)
        withAnimation(HotSlotDesign.titleEditAnimation) {
            isEditingLabel = false
        }
        labelFieldFocused = false
        appState.isInlineEditing = false
        if discards { onDiscardNew() }
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
            .clipShape(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous))
            .allowsHitTesting(false)
        }
    }

    private var needsMixedBackgroundScrims: Bool {
        guard hasContent else { return false }
        return SlotsPalette.isBrandGradient(backgroundHex) || isImageContent
    }

    private var colorSwatch: Color? {
        guard case .text(let string) = slot.content else { return nil }
        return SlotCardCopy.colorFromHex(string.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var isDarkCard: Bool {
        guard case .text(let string) = slot.content else { return false }
        return SlotCardCopy.isHexColor(string.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Color guardado, con el blanco viejo leído como predeterminado.
    private var backgroundHex: String? {
        SlotsPalette.storedBackgroundHex(slot.cardBackgroundHex)
    }

    private var prefersLightContent: Bool {
        guard hasContent else { return false }
        if isImageContent { return true }
        if SlotsPalette.prefersLightContent(hexString: backgroundHex) { return true }
        // Color hex en el portapapeles: la card es oscura salvo que el usuario eligió un fondo claro.
        if isDarkCard, backgroundHex == nil { return true }
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

    /// Identifica vacío, color, degradé o imagen para animar solo esos cambios.
    private var chromePhase: String {
        guard hasContent else { return "empty" }
        if isImageContent, case .image(let fileName) = slot.content { return "image:\(fileName)" }
        if SlotsPalette.isBrandGradient(backgroundHex) { return "gradient" }
        if isDarkCard, backgroundHex == nil { return "ink" }
        return "fill:\(backgroundHex ?? "papel")"
    }

    /// El relleno sólido interpola. Degradé e imagen se funden encima.
    private var chromeFill: Color {
        if !hasContent { return Color.white.opacity(0.28) }
        if let custom = SlotsPalette.color(hexString: backgroundHex) { return custom }
        if isDarkCard { return SlotsColor.cardOscura }
        return SlotsColor.piedra
    }

    @ViewBuilder
    private var cardChrome: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                .fill(chromeFill)

            if hasContent, SlotsPalette.isBrandGradient(backgroundHex) {
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
                .transition(.opacity)
            }

            if hasContent, isImageContent, case .image(let fileName) = slot.content {
                ClipThumbnailView(fileName: fileName, style: .slot)
                    .transition(.opacity)
                LinearGradient(
                    colors: [Color.black.opacity(0.12), Color.black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .transition(.opacity)
            }

            RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                .strokeBorder(
                    hasContent ? Color.clear : (isNewlyCreated ? SlotsColor.naranja : Color.black.opacity(0.22)),
                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                )
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

/// Última card de la grilla: crea un slot vacío al final de la biblioteca.
/// También recibe lo que se suelta encima: un ítem del historial, un archivo o un slot (va al final).
private struct NewSlotCardView: View {
    @Bindable var appState: AppState
    @State private var isHovering = false
    @State private var isDropTarget = false
    /// Aparece una sola vez por apertura del panel, cuando entra en vista al hacer scroll.
    @State private var revealed = false

    var body: some View {
        Button {
            appState.createSlotAndEditName()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isHovering && !isDropTarget ? Color.white : SlotsColor.tinta)
                        .frame(width: 40, height: 40)
                        .background {
                            Circle().fill(isHovering && !isDropTarget ? SlotsColor.tinta : Color.clear)
                        }
                        .overlay {
                            Circle().strokeBorder(
                                SlotsColor.tinta.opacity(isHovering || isDropTarget ? 0 : 0.3), lineWidth: 1.5
                            )
                        }
                    Spacer(minLength: 0)
                    Text("⌘N")
                        .font(SlotsFont.etiqueta)
                        .foregroundStyle(SlotsColor.textoSecundario)
                        .padding(.horizontal, 5)
                        .frame(minHeight: HotSlotDesign.slotHeaderChipHeight)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(SlotsColor.teclaFondo)
                        }
                }
                Spacer(minLength: 0)
                Text(isDropTarget ? "Soltá para crear el slot" : "Nuevo slot")
                    .font(SlotsFont.tituloCard)
                    .foregroundStyle(isDropTarget ? SlotsColor.naranja : SlotsColor.tinta)
                    .lineLimit(2)
                if !isDropTarget {
                    Text("Clic, ⌘N o arrastrá algo del historial")
                        .font(.system(size: 13))
                        .foregroundStyle(SlotsColor.textoSecundario)
                        .padding(.top, 2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                    .fill(isDropTarget ? SlotsColor.naranja.opacity(0.10) : Color.white.opacity(isHovering ? 0.6 : 0.28))
            }
            .overlay {
                RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                    .strokeBorder(
                        isDropTarget ? SlotsColor.naranja : SlotsColor.tinta.opacity(isHovering ? 0.5 : 0.24),
                        style: StrokeStyle(lineWidth: isDropTarget ? 2 : 1.5, dash: [7, 5])
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .onDrop(of: [UTType.hotslotPanelDrag, UTType.fileURL], isTargeted: $isDropTarget) { providers in
            handleDrop(providers)
        }
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 16)
        .scaleEffect(revealed ? 1 : 0.96)
        .onScrollVisibilityChange(threshold: 0.15) { visible in
            guard visible, !revealed else { return }
            withAnimation(.easeOut(duration: 0.3)) { revealed = true }
        }
        .onChange(of: appState.isPanelVisible) { _, visible in
            if visible { revealed = false }
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isDropTarget)
        .help("Nuevo slot al final de la biblioteca")
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, url.isFileURL else { return }
                DispatchQueue.main.async { appState.saveToNewSlot(content: .fileReference(url: url)) }
            }
            return true
        }
        let type = UTType.hotslotPanelDrag.identifier
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(type) }) else {
            return false
        }
        provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
            guard let data, let payload = try? JSONDecoder().decode(PanelDragPayload.self, from: data) else { return }
            DispatchQueue.main.async {
                switch payload {
                case .historyItem(let id):
                    guard let content = appState.historyStore.item(id: id)?.content else { return }
                    appState.saveToNewSlot(content: content)
                case .slot(let source, let library):
                    // Un slot soltado en «Nuevo slot» pasa al final de su propia biblioteca.
                    guard library == appState.libraryWorkspace.workspace.activeLibraryId else { return }
                    appState.moveSlotToEnd(from: source)
                }
            }
        }
        return true
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


/// Cuando dos slots se intercambian: pulso de escala y aro naranja para que se note qué pasó.
private struct SwapFlashModifier: ViewModifier {
    var isSwapped: Bool
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                    .strokeBorder(SlotsColor.naranja, lineWidth: 3)
                    .opacity(isSwapped ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .scaleEffect(pulse ? 1.04 : 1)
            .animation(.easeOut(duration: 0.5), value: isSwapped)
            .onChange(of: isSwapped) { _, swapped in
                guard swapped else { return }
                withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) { pulse = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { pulse = false }
                }
            }
    }
}
