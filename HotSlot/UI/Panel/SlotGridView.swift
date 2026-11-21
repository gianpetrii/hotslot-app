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
    /// Posición de cada card (por número de slot) dentro del contenido, para animar el intercambio.
    @State private var cardFrames: [Int: CGRect] = [:]
    @State private var gridFrame: CGRect = .zero
    /// Cursor (en coordenadas de la grilla) mientras se arrastra un slot; la card flotante lo sigue.
    @State private var dragCursor: CGPoint?
    @State private var dragReleasedAt: Date?

    /// Franja (en pt) donde, mientras arrastrás, la grilla se desplaza sola.
    private static let autoScrollZone: CGFloat = 56

    /// Ventana del panel, para leer el cursor real (durante un arrastre macOS no entrega eventos de mouse).
    private var panelWindow: NSWindow? {
        NSApp.windows.first(where: { $0.isVisible && String(describing: type(of: $0)) == "FloatingPanel" })
    }

    /// Posición del cursor en coordenadas de la grilla (origen arriba a la izquierda).
    private func cursorInGrid() -> CGPoint? {
        guard let window = panelWindow, let contentHeight = window.contentView?.bounds.height,
              gridFrame.height > 0 else { return nil }
        let point = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        return CGPoint(x: point.x - gridFrame.minX, y: contentHeight - point.y - gridFrame.minY)
    }

    /// Cada cuadro: sigue el cursor mientras se arrastra un slot, cierra el arrastre si se soltó sin destino
    /// y desplaza la grilla si el cursor está cerca de un borde.
    private func dragTick() {
        // Con el panel cerrado y sin arrastre no hay nada que revisar (el reloj corre 40 veces por segundo).
        guard appState.isPanelVisible || appState.slotDragSource != nil || dragCursor != nil else { return }
        let pressed = NSEvent.pressedMouseButtons & 1 != 0
        if appState.slotDragSource != nil {
            if pressed {
                dragReleasedAt = nil
                dragCursor = cursorInGrid()
            } else if let released = dragReleasedAt {
                // Se soltó y el drop no llegó a resolverlo: se resuelve acá por la posición del cursor.
                if Date().timeIntervalSince(released) > 0.08, let drag = appState.slotDragSource {
                    let destination = cardUnderCursor()
                    appState.slotDragSource = nil
                    if let destination, destination != drag.index, drag.libraryId == appState.libraryWorkspace.workspace.activeLibraryId {
                        let pose = dropPose(destination: destination, grab: drag.grab, size: drag.size)
                        appState.reorderSlot(from: drag.index, to: destination, dropOffset: pose.offset, dropScale: pose.scale)
                    }
                    dragReleasedAt = nil
                    dragCursor = nil
                }
            } else {
                dragReleasedAt = Date()
            }
        } else if dragCursor != nil {
            dragCursor = nil
        }
        guard pressed, appState.isPanelVisible, let cursor = dragCursor ?? cursorInGrid() else { return }
        guard cursor.x >= 0, cursor.x <= gridFrame.width else { return }
        let y = cursor.y
        let zone = Self.autoScrollZone
        var delta: CGFloat = 0
        if y > gridFrame.height - zone, y < gridFrame.height + zone {
            delta = min(1, (y - (gridFrame.height - zone)) / zone) * 14
        } else if y < zone, y > -zone {
            delta = -min(1, (zone - y) / zone) * 14
        }
        guard delta != 0 else { return }
        let maxOffset = max(0, scrollMetrics.content - scrollMetrics.viewport)
        let target = min(max(scrollMetrics.offset + delta, 0), maxOffset)
        guard target != scrollMetrics.offset else { return }
        scrollPosition.scrollTo(y: target)
    }

    /// Slot cuya card está bajo el cursor (por posición, no por quién recibió el drop).
    private func cardUnderCursor() -> Int? {
        guard let cursor = cursorInGrid() else { return nil }
        let point = CGPoint(x: cursor.x + shadowSide, y: cursor.y + shadowVertical + scrollMetrics.offset)
        return cardFrames.first(where: { $0.value.contains(point) })?.key
    }

    /// Pose de partida del slot soltado: su esquina donde estaba la card flotante, respecto de la card destino.
    private func dropPose(destination: Int, grab: CGPoint, size: CGSize) -> (offset: CGSize, scale: CGSize) {
        guard let cursor = cursorInGrid(), let frame = cardFrames[destination], frame.width > 0, frame.height > 0 else {
            return (.zero, CGSize(width: 1, height: 1))
        }
        // De coordenadas de la grilla a las del contenido que se desplaza.
        let corner = CGPoint(
            x: cursor.x - grab.x + shadowSide,
            y: cursor.y - grab.y + shadowVertical + scrollMetrics.offset
        )
        let pose = (
            offset: CGSize(width: corner.x - frame.minX, height: corner.y - frame.minY),
            scale: CGSize(width: size.width / frame.width, height: size.height / frame.height)
        )
        return pose
    }

    /// El slot que se está arrastrando, dibujado por nosotros bajo el cursor (la imagen del sistema va invisible).
    @ViewBuilder
    private var dragFloat: some View {
        if let drag = appState.slotDragSource, let cursor = dragCursor,
           let slot = appState.slotStore.allSlots.first(where: { $0.index == drag.index }) {
            slotCardView(for: slot)
                .frame(width: drag.size.width, height: drag.size.height)
                .shadow(color: Color.black.opacity(0.22), radius: 14, y: 6)
                .offset(x: cursor.x - drag.grab.x, y: cursor.y - drag.grab.y)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
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
                                    .transition(.slotArrival)
                                    .id(slot.index)
                            }
                            NewSlotCardView(appState: appState)
                            .frame(height: rowHeight)
                            .id(Self.newSlotAnchor)
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: extraSlots.map(\.index))
                    }
                    .padding(.horizontal, shadowSide)
                    .padding(.vertical, shadowVertical)
                    .coordinateSpace(name: Self.contentSpace)
                    .overlay(alignment: .topLeading) { swapOverlay }
                    .background(HideNativeScrollers())
                }
                .scrollIndicators(.hidden)
                .scrollPosition($scrollPosition)
                .onReceive(Timer.publish(every: 1.0 / 40.0, on: .main, in: .common).autoconnect()) { _ in
                    dragTick()
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
                .onChange(of: appState.librarySwitchRevision) { _, _ in
                    proxy.scrollTo(Self.topAnchor, anchor: .top)
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
        .overlay(alignment: .topLeading) { dragFloat }
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
                // Centrada en el hueco entre la grilla y el historial (el recorte llega `shadowSide` más allá).
                .padding(.trailing, shadowSide - (HotSlotDesign.panelBodyGap / 2 + 2.5))
                .allowsHitTesting(false)
        }
    }

    private static let contentSpace = "slotGridContent"
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
            Text("Sin atajo de fábrica · asignale uno desde la card o arrastralo arriba de esta línea")
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
            slotCardView(for: slot)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.contentSpace)) } action: { cardFrames[index] = $0 }
                // Durante el intercambio las dos cards se dibujan encima de todo (ver `swapOverlay`); acá queda el hueco.
                .opacity(isSwapped(index) ? 0 : (appState.slotDragSource?.index == index ? 0.35 : 1))
                .slotArrival(appState.slotArrival?.index == index)
        }
    }

    private func slotCardView(for slot: Slot) -> some View {
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
                onSwapFrom: { sourceIndex, grab, size in
                    // El sistema entrega el drop a la card donde empezó el arrastre: el destino real se resuelve por el cursor.
                    let destination = cardUnderCursor() ?? slot.index
                    guard destination != sourceIndex else { return }
                    let pose = dropPose(destination: destination, grab: grab, size: size)
                    appState.reorderSlot(from: sourceIndex, to: destination, dropOffset: pose.offset, dropScale: pose.scale)
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
                },
                onDelete: slot.index > SlotStore.slotCount && slot.content == nil ? {
                    withAnimation(.easeInOut(duration: 0.22)) { appState.deleteSlot(index: slot.index) }
                } : nil
            )
            .opacity(slotSearchOpacity(for: slot))
    }

    /// Las dos cards del intercambio, por encima de toda la grilla:
    /// el slot arrastrado se asienta desde donde lo soltaste y, después, el desplazado viaja al lugar libre.
    @ViewBuilder
    private var swapOverlay: some View {
        if let swap = appState.swapHighlight,
           let other = swap.indices.first(where: { $0 != swap.landed }),
           let landedFrame = cardFrames[swap.landed], let displacedFrame = cardFrames[other],
           let landedSlot = appState.slotStore.allSlots.first(where: { $0.index == swap.landed }),
           let displacedSlot = appState.slotStore.allSlots.first(where: { $0.index == other }) {
            ZStack(alignment: .topLeading) {
                // Abajo: el desplazado sale de debajo del arrastrado, pero pasa por encima del resto de las cards.
                SwapFlyer(
                    frame: displacedFrame,
                    startOffset: CGSize(width: landedFrame.minX - displacedFrame.minX, height: landedFrame.minY - displacedFrame.minY),
                    startScale: CGSize(width: landedFrame.width / displacedFrame.width, height: landedFrame.height / displacedFrame.height),
                    running: swap.running,
                    delay: 0.24,
                    hiddenUntilMoving: true
                ) { slotCardView(for: displacedSlot) }
                // Arriba: el arrastrado, que arranca donde lo soltaste.
                SwapFlyer(
                    frame: landedFrame,
                    startOffset: swap.landOffset,
                    startScale: swap.landScale,
                    running: swap.running,
                    delay: 0,
                    hiddenUntilMoving: false
                ) { slotCardView(for: landedSlot) }
            }
            .allowsHitTesting(false)
        }
    }

    private func isSwapped(_ index: Int) -> Bool {
        appState.swapHighlight?.indices.contains(index) == true
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
    /// Origen del slot arrastrado, punto por donde se lo agarró y tamaño de su card.
    let onSwapFrom: (Int, CGPoint, CGSize) -> Void
    let onUpdateLabel: (String) -> Void
    let onSetBackground: (String?) -> Void
    let onReplaceFromClipboard: () -> Void
    let onMoveToLibrary: (UUID) -> Void
    let onDiscardNew: () -> Void
    /// Solo los slots sin atajo de fábrica (6 en adelante) se pueden eliminar.
    var onDelete: (() -> Void)?
    @State private var didStartNewSlotEdit = false
    @State private var isHovering = false
    @State private var cardSize: CGSize = .zero
    @State private var grabPoint: CGPoint = .zero
    @State private var isDropTarget = false
    @State private var isEditingShortcuts = false
    @State private var isEditingLabel = false
    @State private var labelDraft = ""
    @State private var copyFlash = false
    @FocusState private var labelFieldFocused: Bool
    @Environment(AppState.self) private var appState

    private var hasContent: Bool { slot.content != nil }

    /// Esta card es la que se acaba de copiar con un clic (feedback igual al de iOS).
    private var isCopied: Bool { appState.copiedSlotIndex == slot.index }
    /// Hay otra card copiada: esta se apaga para que se note cuál fue.
    private var isDimmedByCopy: Bool {
        guard let copied = appState.copiedSlotIndex else { return false }
        return copied != slot.index
    }

    /// Slot que acaba de crearse con «Nuevo slot» y todavía no tiene contenido.
    private var isNewlyCreated: Bool {
        appState.pendingNewSlot == slot.index && !hasContent
    }

    private func startNewSlotEditIfNeeded() {
        guard isNewlyCreated, !didStartNewSlotEdit, !isEditingLabel else { return }
        didStartNewSlotEdit = true
        beginLabelEdit()
    }

    /// Atajo que muestra la card, por posición. Los primeros 5 traen uno de fábrica;
    /// del 6 en adelante solo si el usuario se lo asignó.
    private var visibleShortcut: KeyboardShortcuts.Name? {
        let name = hasContent
            ? KeyboardShortcuts.Name.pasteSlotName(slot.index)
            : KeyboardShortcuts.Name.copyToSlotName(slot.index)
        if slot.index <= SlotStore.slotCount { return name }
        _ = appState.shortcutEpoch
        return KeyboardShortcuts.getShortcut(for: name) == nil ? nil : name
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
        .slotsHoverLift(isHovering && hasContent && !copyFlash && !isCopied, scales: true)
        // Recién copiada: se achica un poco con un resplandor naranja; las otras se apagan.
        .scaleEffect(isCopied ? 0.97 : 1)
        .shadow(color: Color(slotsHex: 0xE2470F).opacity(isCopied ? 0.35 : 0), radius: 15, y: 14)
        .opacity(isDimmedByCopy ? 0.55 : 1)
        .zIndex(isCopied ? 1 : 0)
        .contentShape(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous))
        .onTapGesture {
            if isEditingLabel {
                commitLabelEdit()
                return
            }
            confirmCopy()
        }
        .onHover { isHovering = $0 }
        .onContinuousHover { phase in
            if case .active(let point) = phase { grabPoint = point }
        }
        .onDrag { makeDragProvider() } preview: { Color.clear.frame(width: 1, height: 1) }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { cardSize = $0 }
        .onDrop(of: [UTType.hotslotPanelDrag, UTType.hotslotSlotDrag, UTType.fileURL], isTargeted: $isDropTarget) { providers, location in
            handleSlotCardDrop(providers, location: location)
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
            guard visible else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                copyFlash = false
                appState.copiedSlotIndex = nil
            }
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
            if let onDelete, isHovering {
                Button(action: onDelete) {
                    SlotHeaderActionChip(systemImage: "trash", foreground: headerChipInk, plate: headerChipPlate)
                }
                .buttonStyle(.plain)
                .help("Eliminar slot")
                .transition(.opacity.combined(with: .scale(scale: 0.88)))
            } else if hasContent, isHovering {
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

            if isCopied {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(prefersLightContent ? SlotsColor.naranja : Color.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(prefersLightContent ? Color.white : SlotsColor.naranja))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else if let visibleShortcut {
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
                // Sin atajo de fábrica: un clic abre el editor para asignarle uno.
                Button {
                    isEditingShortcuts = true
                } label: {
                    Text("+ Atajo")
                        .font(SlotsFont.etiqueta)
                        .foregroundStyle(headerChipInk.opacity(0.8))
                        .padding(.horizontal, 5)
                        .frame(minHeight: HotSlotDesign.slotHeaderChipHeight)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(headerChipPlate)
                        }
                }
                .buttonStyle(.plain)
                .help("Este slot no tiene atajo · clic para asignarle uno")
                .popover(isPresented: $isEditingShortcuts, arrowEdge: .leading) {
                    SlotShortcutEditorPopover(slotIndex: slot.index)
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
        if appState.settings.clickItemAction == .copyToClipboard {
            // Feedback de iOS: «Copiado» en el título, tilde y resplandor. Aparece de golpe, sin animación; la duración del cierre del panel no cambia.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { appState.copiedSlotIndex = slot.index }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { copyFlash = true }
        }
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
                    Text(isCopied ? "Copiado" : SlotCardCopy.visibleCardTitle(for: slot))
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
        if let onDelete {
            Button("Eliminar slot", role: .destructive) { onDelete() }
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

    private func makeDragProvider() -> NSItemProvider {
        let library = appState.libraryWorkspace.workspace.activeLibraryId
        // El punto por donde agarraste la card: lo último que vio el mouse antes de empezar a arrastrar.
        appState.slotDragSource = (slot.index, library, grabPoint, cardSize)
        let data = try? JSONEncoder().encode(PanelDragPayload.slot(index: slot.index, libraryId: library))
        let provider = NSItemProvider()
        for type in [UTType.hotslotPanelDrag, UTType.hotslotSlotDrag] {
            provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .all) { completion in
                completion(data, nil)
                return nil
            }
        }
        return provider
    }

    private func handleSlotCardDrop(_ providers: [NSItemProvider], location: CGPoint) -> Bool {
        // Otro slot de este panel: se resuelve en el acto, así el movimiento arranca al soltar y no después.
        if providers.contains(where: { $0.hasItemConformingToTypeIdentifier(UTType.hotslotSlotDrag.identifier) }),
           let drag = appState.slotDragSource {
            appState.slotDragSource = nil
            let activeLibrary = appState.libraryWorkspace.workspace.activeLibraryId
            if drag.libraryId == activeLibrary {
                onSwapFrom(drag.index, drag.grab, drag.size)
            } else {
                appState.moveSlotToLibrary(
                    slotIndex: drag.index, fromLibraryId: drag.libraryId,
                    libraryId: activeLibrary, toOrder: slot.index
                )
            }
            return true
        }
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
                    // Respaldo (arrastre sin marca de slot): se asume agarrado del centro.
                    onSwapFrom(source, CGPoint(x: cardSize.width / 2, y: cardSize.height / 2), cardSize)
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

struct SlotReadableText: ViewModifier {
    var onDark: Bool

    func body(content: Content) -> some View {
        content.shadow(color: Color.black.opacity(onDark ? 0.55 : 0), radius: 5, y: 1)
    }
}

struct SlotHeaderActionChip: View {
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


/// Card que se mueve encima de la grilla durante el intercambio. Arranca en la pose dada (posición y tamaño
/// del otro slot, o donde lo soltaste) y llega a la suya; `delay` la hace esperar su turno.
private struct SwapFlyer<Content: View>: View {
    let frame: CGRect
    let startOffset: CGSize
    let startScale: CGSize
    let running: Bool
    let delay: Double
    let hiddenUntilMoving: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(width: frame.width, height: frame.height)
            .scaleEffect(x: running ? 1 : startScale.width, y: running ? 1 : startScale.height, anchor: .topLeading)
            .offset(running ? .zero : startOffset)
            .animation(.spring(response: delay > 0 ? 0.42 : 0.34, dampingFraction: delay > 0 ? 0.84 : 0.82).delay(delay), value: running)
            .opacity(hiddenUntilMoving && !running ? 0 : 1)
            .animation(.easeOut(duration: 0.1).delay(delay), value: running)
            .offset(x: frame.minX, y: frame.minY)
    }
}
