import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

/// Pantalla principal: la grilla de la biblioteca activa y la barra de bibliotecas.
struct SlotsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    // Copiar
    @State private var copiedSlotId: UUID?
    @State private var toast: CopiedToast.Message?
    @State private var resetTask: Task<Void, Never>?

    // Editar
    @State private var isEditing = false
    @State private var draggingId: UUID?
    @State private var dropTargetId: UUID?
    // Intercambio: card flotante que sigue al dedo y aterrizaje animado (igual que el Mac).
    @State private var cardFrames: [UUID: CGRect] = [:]
    @State private var dragCursor: CGPoint?
    @State private var dragGrab: CGPoint?
    @State private var dragLastUpdate = Date()
    @State private var swapAnim: SwapAnim?
    @State private var newSlot: NewSlotSheet.Request?
    @State private var editSlot: EditSlotSheet.Request?
    @State private var showNewLibrary = false
    @State private var newSlotId: UUID?
    @State private var showSettings = false

    // Borrar con deshacer
    @State private var undo: UndoNotice?
    @State private var undoTask: Task<Void, Never>?

    // Bibliotecas
    @State private var renaming: Library?
    @State private var renameText = ""
    @State private var deleting: Library?
    @State private var clipboardAvailable = false

    /// Los dos slots que acaban de intercambiarse. `landed` es el que se soltó; `other` el desplazado.
    struct SwapAnim {
        var landed: UUID
        var other: UUID
        var landedFrame: CGRect
        var otherFrame: CGRect
        var landOffset: CGSize
        var landScale: CGSize
        var running = false
    }

    struct UndoNotice: Equatable {
        var slot: SlotRecord
        var message: String
    }

    private var store: LibraryWorkspaceStore { model.store }
    private var activeLibrary: Library? { store.activeLibrary }
    private var slots: [SlotRecord] { store.activeSlots() }
    private var hasContent: Bool { slots.contains { $0.clipContent() != nil } }

    /// Todavía no se guardó nada en ninguna biblioteca.
    private var isFirstRun: Bool {
        !store.workspace.slots.contains { $0.clipContent() != nil }
    }

    var body: some View {
        VStack(spacing: SlotsSpace.m) {
            header
            ScrollView {
                VStack(spacing: SlotsSpace.m) {
                    if hasContent || isEditing {
                        grid
                    } else {
                        EmptyLibraryView(
                            libraryName: isFirstRun ? nil : activeLibrary?.name,
                            clipboardAvailable: clipboardAvailable,
                            onUseClipboard: { newSlot = .init(useClipboard: true) }
                        )
                        Button("Abrir Slots más rápido") { showSettings = true }
                            .slotsText(13)
                            .foregroundStyle(SlotsColor.tinta)
                    }
                    if isEditing {
                        Text("Arrastrá para reordenar · Tocá una tarjeta para editarla")
                            .slotsText(13, medium: false)
                            .foregroundStyle(SlotsColor.textoSecundario)
                            .multilineTextAlignment(.center)
                        Button("Ajustes · Abrir Slots más rápido") { showSettings = true }
                            .slotsText(13)
                            .foregroundStyle(SlotsColor.tinta)
                            .padding(.top, SlotsSpace.xs)
                    }
                }
                .padding(.bottom, SlotsSpace.m)
                .id(store.workspace.activeLibraryId)
                .transition(.opacity)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: isEditing ? 0 : 64) }
        }
        .padding(.horizontal, SlotsSpace.m)
        .padding(.top, 4)
        .background(SlotsColor.papel.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            VStack(spacing: SlotsSpace.s) {
                if let undo { undoPill(undo) }
                if !isEditing { libraryBar }
            }
        }
        .overlay(alignment: .top) { toastLayer }
        .statusBarHidden(toast != nil)
        .sheet(item: $newSlot) { request in
            NewSlotSheet(request: request) { slotId, libraryId in
                withAnimation(.easeInOut(duration: 0.15)) { store.setActiveLibrary(id: libraryId) }
                highlightNew(slotId)
            }
        }
        .fullScreenCover(item: $editSlot) { request in
            EditSlotSheet(request: request) { delete($0) }
        }
        .sheet(isPresented: $showNewLibrary) { NewLibrarySheet() }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        .alert("Renombrar biblioteca", isPresented: .init(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Nombre", text: $renameText)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") {
                if let renaming, !model.isLibraryNameTaken(renameText, excluding: renaming.id) {
                    store.renameLibrary(id: renaming.id, name: renameText)
                }
            }
        }
        .confirmationDialog(
            deleting.map { "¿Eliminar «\($0.name)»?" } ?? "",
            isPresented: .init(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("Eliminar biblioteca", role: .destructive) {
                if let deleting {
                    withAnimation(.easeInOut(duration: 0.15)) { _ = store.deleteLibrary(id: deleting.id) }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borran también todos sus slots, en todos tus dispositivos.")
        }
        .onAppear { clipboardAvailable = ClipboardReader.hasContent }
        // Los widgets muestran los slots: se refrescan cuando cambian (acá o desde iCloud).
        .onChange(of: store.workspace) { _, _ in WidgetCenter.shared.reloadAllTimelines() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { clipboardAvailable = ClipboardReader.hasContent }
        }
    }

    // MARK: - Cabecera

    private var header: some View {
        HStack(spacing: SlotsSpace.s) {
            Text(isEditing ? "Editar" : (activeLibrary?.name ?? "Slots"))
                .slotsText(44, tracking: -0.04, lineHeight: 1)
                .foregroundStyle(SlotsColor.tinta)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: SlotsSpace.s)
            Button { newSlot = .init() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isEditing ? SlotsColor.tinta : .white)
                    .frame(width: 48, height: 48)
                    .background(isEditing ? SlotsColor.botonSecundario : SlotsColor.tinta, in: Circle())
            }
            .accessibilityLabel("Nuevo slot")
            if isEditing {
                Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { isEditing = false } } label: {
                    Text("Listo")
                        .slotsText(15)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 48)
                        .background(SlotsColor.tinta, in: Capsule())
                }
            } else {
                Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { isEditing = true } } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(SlotsColor.tinta)
                        .frame(width: 48, height: 48)
                        .background(SlotsColor.botonSecundario, in: Circle())
                }
                .accessibilityLabel("Editar slots")
            }
        }
        .buttonStyle(.plain)
    }

    private var libraryBar: some View {
        LibraryBar(
            libraries: model.libraries,
            activeId: store.workspace.activeLibraryId,
            count: { store.filledSlotCount(in: $0) },
            onSelect: { id in
                withAnimation(.easeInOut(duration: 0.15)) { store.setActiveLibrary(id: id) }
            },
            onAdd: { showNewLibrary = true },
            onRename: { library in
                renameText = library.name
                renaming = library
            },
            onDelete: { deleting = $0 },
            onMove: { id, index in
                withAnimation(.easeOut(duration: 0.2)) { store.moveLibrary(id: id, toIndex: index) }
            }
        )
    }

    // MARK: - Grilla

    private func cardView(_ slot: SlotRecord, copied: Bool = false, handle: Bool = false) -> some View {
        SlotCardView(
            slot: slot,
            isCopied: copied,
            showsHandle: handle,
            isDropTarget: dropTargetId == slot.id && draggingId != slot.id
        )
    }

    private var isDragActive: Bool { draggingId != nil && dragCursor != nil && Date().timeIntervalSince(dragLastUpdate) < 1.5 }

    private var grid: some View {
        SlotGridLayout {
            ForEach(slots) { slot in
                let isCopied = copiedSlotId == slot.id
                let hiddenBySwap = swapAnim.map { $0.landed == slot.id || $0.other == slot.id } ?? false
                Button { tap(slot) } label: {
                    cardView(slot, copied: isCopied, handle: isEditing)
                }
                .buttonStyle(SlotCardButtonStyle())
                .contextMenu { menu(for: slot) }
                .accessibilityAction(named: "Editar") { if slot.clipContent() != nil { editSlot = .init(slotId: slot.id) } }
                .accessibilityAction(named: slot.clipContent() == nil ? "Eliminar" : "Vaciar") { delete(slot.id) }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.gridSpace)) } action: { cardFrames[slot.id] = $0 }
                .onDrag {
                    draggingId = slot.id
                    dragCursor = nil
                    dragGrab = nil
                    let provider = NSItemProvider()
                    // Solo sirve dentro de Slots: en otra app no suelta nada.
                    provider.registerDataRepresentation(forTypeIdentifier: UTType.data.identifier, visibility: .ownProcess) { done in
                        done(Data(slot.id.uuidString.utf8), nil)
                        return nil
                    }
                    return provider
                } preview: {
                    // La card que se mueve la dibuja Slots, no el sistema.
                    Color.clear.frame(width: 1, height: 1)
                }
                .slotRowSpan(SlotCardView.rowSpan(for: slot))
                .scaleEffect(isCopied ? 0.97 : (newSlotId == slot.id ? 0.9 : 1))
                .shadow(color: Color(slotsHex: 0xE2470F).opacity(isCopied ? 0.35 : 0), radius: 15, y: 14)
                .opacity(hiddenBySwap || newSlotId == slot.id ? 0
                         : (isDragActive && draggingId == slot.id ? 0.35 : (copiedSlotId != nil && !isCopied ? 0.55 : 1)))
                .zIndex(isCopied ? 1 : 0)
            }
        }
        .coordinateSpace(name: Self.gridSpace)
        .overlay(alignment: .topLeading) { swapOverlay }
        .overlay(alignment: .topLeading) { dragFloat }
        .onDrop(of: [.data], delegate: GridDropDelegate(
            onUpdate: { location in dragUpdated(location) },
            onExit: { dropTargetId = nil },
            onDrop: { location in dropped(at: location) }
        ))
    }

    private static let gridSpace = "slotsGrid"

    private func cardId(at point: CGPoint) -> UUID? {
        cardFrames.first(where: { $0.value.contains(point) })?.key
    }

    private func dragUpdated(_ location: CGPoint) {
        guard let source = draggingId, let frame = cardFrames[source] else { return }
        if dragGrab == nil {
            dragGrab = CGPoint(
                x: min(max(location.x - frame.minX, 0), frame.width),
                y: min(max(location.y - frame.minY, 0), frame.height)
            )
        }
        dragCursor = location
        dragLastUpdate = Date()
        let target = cardId(at: location)
        dropTargetId = target == source ? nil : target
    }

    @ViewBuilder private var dragFloat: some View {
        if isDragActive, let id = draggingId, let cursor = dragCursor, let grab = dragGrab,
           let frame = cardFrames[id], let slot = store.slot(id: id) {
            cardView(slot)
                .frame(width: frame.width, height: frame.height)
                .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
                .offset(x: cursor.x - grab.x, y: cursor.y - grab.y)
                .allowsHitTesting(false)
        }
    }

    /// Suelta: intercambia los contenidos y anima. La card soltada aterriza desde donde la dejó el dedo;
    /// la desplazada vuela hasta el lugar de origen un instante después.
    private func dropped(at location: CGPoint) -> Bool {
        defer {
            draggingId = nil
            dropTargetId = nil
            dragCursor = nil
            dragGrab = nil
        }
        guard let source = draggingId, let target = cardId(at: location), target != source,
              let sourceFrame = cardFrames[source], let targetFrame = cardFrames[target] else { return false }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let grab = dragGrab ?? CGPoint(x: sourceFrame.width / 2, y: sourceFrame.height / 2)
        // Cada slot conserva su id y cambia de posición: el soltado queda donde estaba el otro.
        model.swap(source, target)
        guard !reduceMotion else { return true }
        let anim = SwapAnim(
            landed: source,
            other: target,
            landedFrame: targetFrame,
            otherFrame: sourceFrame,
            landOffset: CGSize(width: location.x - grab.x - targetFrame.minX, height: location.y - grab.y - targetFrame.minY),
            landScale: CGSize(width: sourceFrame.width / max(targetFrame.width, 1), height: sourceFrame.height / max(targetFrame.height, 1))
        )
        swapAnim = anim
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(20))
            swapAnim?.running = true
            try? await Task.sleep(for: .milliseconds(900))
            swapAnim = nil
        }
        return true
    }

    @ViewBuilder private var swapOverlay: some View {
        if let swap = swapAnim,
           let landedSlot = store.slot(id: swap.landed), let otherSlot = store.slot(id: swap.other) {
            let landedFrame = swap.landedFrame
            let otherFrame = swap.otherFrame
            ZStack(alignment: .topLeading) {
                SwapFlyer(
                    frame: otherFrame,
                    startOffset: CGSize(width: landedFrame.minX - otherFrame.minX, height: landedFrame.minY - otherFrame.minY),
                    startScale: CGSize(width: landedFrame.width / max(otherFrame.width, 1), height: landedFrame.height / max(otherFrame.height, 1)),
                    running: swap.running,
                    delay: 0.24,
                    hiddenUntilMoving: true
                ) { cardView(otherSlot) }
                SwapFlyer(
                    frame: landedFrame,
                    startOffset: swap.landOffset,
                    startScale: swap.landScale,
                    running: swap.running,
                    delay: 0,
                    hiddenUntilMoving: false
                ) { cardView(landedSlot) }
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder private func menu(for slot: SlotRecord) -> some View {
        if let content = slot.clipContent() {
            Button("Editar", systemImage: "pencil") {
                editSlot = .init(slotId: slot.id)
            }
            Menu("Color de fondo", systemImage: "paintpalette") {
                backgroundButton("Predeterminado (Piedra)", hex: nil, slot: slot)
                backgroundButton("Degradé naranja (marca)", hex: SlotsPalette.brandGradientAsset, slot: slot)
                ForEach(SlotsPalette.slotBackgrounds, id: \.hex) { entry in
                    backgroundButton(entry.name, hex: SlotsPalette.normalizedHex(entry.hex), slot: slot)
                }
            }
            if clipboardAvailable {
                Button("Reemplazar", systemImage: "arrow.left.arrow.right") { replace(slot) }
            }
            let others = model.libraries.filter { $0.id != slot.libraryId }
            if others.count == 1, let other = others.first {
                Button("Mover a \(other.name)", systemImage: "arrow.right") { move(slot, to: other.id) }
            } else if !others.isEmpty {
                Menu("Mover a…", systemImage: "arrow.right") {
                    ForEach(others) { library in
                        Button(library.name) { move(slot, to: library.id) }
                    }
                }
            }
            Divider()
            Button("Vaciar slot", systemImage: "trash", role: .destructive) { delete(slot.id) }
        } else {
            Button("Agregar contenido", systemImage: "plus") { newSlot = .init(slotId: slot.id) }
            if clipboardAvailable {
                Button("Pegar portapapeles", systemImage: "doc.on.clipboard") { replace(slot) }
            }
            if model.canRemove(slot) {
                Divider()
                Button("Eliminar slot", systemImage: "trash", role: .destructive) { delete(slot.id) }
            }
        }
    }

    private func backgroundButton(_ name: String, hex: String?, slot: SlotRecord) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { model.setBackground(slotId: slot.id, hex: hex) }
        } label: {
            Label {
                Text(name) + Text(SlotsPalette.storedBackgroundHex(slot.cardBackgroundHex) == hex ? "  ✓" : "")
            } icon: {
                Image(uiImage: Self.colorDot(hex))
                    .renderingMode(.original)
            }
        }
    }

    /// Círculo de color para el menú de fondos, igual que en el Mac.
    private static func colorDot(_ hex: String?) -> UIImage {
        let size = CGSize(width: 16, height: 16)
        return UIGraphicsImageRenderer(size: size).image { context in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            let value = SlotsPalette.isBrandGradient(hex) ? 0xE2501D : (hex.flatMap { UInt32($0.dropFirst(), radix: 16) } ?? 0xE6E3DE)
            UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            ).setFill()
            UIBezierPath(ovalIn: rect).fill()
            UIColor.black.withAlphaComponent(0.2).setStroke()
            let ring = UIBezierPath(ovalIn: rect)
            ring.lineWidth = 0.5
            ring.stroke()
        }
    }

    // MARK: - Acciones

    /// Tocar copia. En modo Editar abre la hoja de edición. Un slot vacío abre «Nuevo slot».
    private func tap(_ slot: SlotRecord) {
        guard let content = slot.clipContent() else {
            newSlot = .init(slotId: slot.id)
            return
        }
        if isEditing {
            editSlot = .init(slotId: slot.id)
            return
        }
        resetTask?.cancel()
        let title = SlotCardText.title(slot)

        guard model.copy(slot) else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            let detail = content.isRemoteOnlyFile ? "Solo en otro dispositivo" : title
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                copiedSlotId = nil
                toast = .init(label: "No se pudo copiar", detail: detail, isError: true)
            }
            scheduleReset()
            return
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.2)) { copiedSlotId = slot.id }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            toast = .init(label: "Copiado", detail: title)
        }
        scheduleReset()
    }

    private func replace(_ slot: SlotRecord) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if model.replaceFromClipboard(slotId: slot.id) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private func move(_ slot: SlotRecord, to libraryId: UUID) {
        withAnimation(.easeOut(duration: 0.2)) { model.move(slotId: slot.id, toLibraryId: libraryId) }
    }

    /// Borrar no pide confirmación: aparece la píldora con «Deshacer» durante 4 s.
    private func delete(_ slotId: UUID) {
        var removed: SlotRecord?
        withAnimation(.easeOut(duration: 0.2)) { removed = model.delete(slotId: slotId) }
        guard let removed else { return }
        let wasEmpty = removed.clipContent() == nil
        let title = SlotCardText.title(removed)
        undoTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            undo = UndoNotice(slot: removed, message: wasEmpty ? "Quitaste “\(title)”" : "Borraste “\(title)”")
        }
        undoTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { undo = nil }
        }
    }

    private func undoPill(_ notice: UndoNotice) -> some View {
        HStack(spacing: SlotsSpace.s) {
            Text(notice.message)
                .slotsText(15)
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: SlotsSpace.s)
            Button {
                undoTask?.cancel()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    model.undoDelete(notice.slot)
                    undo = nil
                }
            } label: {
                Text("Deshacer")
                    .slotsText(14)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(SlotsColor.naranja, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .frame(height: 56)
        .background(SlotsColor.tinta, in: Capsule())
        .padding(.horizontal, SlotsSpace.m)
        .padding(.bottom, isEditing ? SlotsSpace.s : 0)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// La card nueva entra con fade y escala desde 0,9.
    private func highlightNew(_ slotId: UUID) {
        newSlotId = slotId
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.easeOut(duration: 0.3)) { newSlotId = nil }
        }
    }

    // MARK: - Aviso «Copiado»

    private var toastLayer: some View {
        GeometryReader { proxy in
            // Con Dynamic Island el aviso la envuelve y sale de ella; si no, baja como píldora bajo la barra de estado.
            let safeTop = proxy.safeAreaInsets.top
            let hasIsland = safeTop >= 51
            ZStack(alignment: .top) {
                Color.clear
                if let toast {
                    CopiedToast(
                        message: toast,
                        width: hasIsland ? min(proxy.size.width - 32, 370) : 300,
                        height: hasIsland ? 44 : 40,
                        centerGap: hasIsland ? 132 : 0
                    )
                    .padding(.top, hasIsland ? 11 : safeTop + 4)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.4, anchor: .top).combined(with: .opacity)
                    )
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .allowsHitTesting(false)
    }

    /// Cuánto dura el estado «Copiado». En Debug se puede alargar con `-slotsToastSeconds 8` para sacar capturas.
    private static var copiedDuration: Double {
        #if DEBUG
        let custom = UserDefaults.standard.double(forKey: "slotsToastSeconds")
        if custom > 0 { return custom }
        #endif
        return 1.5
    }

    /// A los 1,5 s todo vuelve solo al estado normal.
    private func scheduleReset() {
        resetTask = Task {
            try? await Task.sleep(for: .seconds(Self.copiedDuration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                copiedSlotId = nil
                toast = nil
            }
        }
    }
}

/// Soltar una card sobre otra las intercambia.
private struct GridDropDelegate: DropDelegate {
    let onUpdate: (CGPoint) -> Void
    let onExit: () -> Void
    let onDrop: (CGPoint) -> Bool

    func dropEntered(info: DropInfo) { onUpdate(info.location) }
    func dropExited(info: DropInfo) { onExit() }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        onUpdate(info.location)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool { onDrop(info.location) }
}

/// Una card que vuela de su pose inicial (desplazada y escalada) a su lugar, con el mismo resorte del Mac.
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
