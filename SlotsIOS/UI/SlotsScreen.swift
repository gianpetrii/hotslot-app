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
    @State private var swapAnim: SwapAnim?
    // Arrastrar un slot sobre una pill de biblioteca: a los 0,6 s cambia a esa biblioteca.
    @State private var hoverPill: UUID?
    @State private var hoverTask: Task<Void, Never>?
    // Renombrar un slot desde el menú.
    @State private var renameRequest: RenameRequest?
    @AppStorage("confirmLibraryDelete") private var confirmLibraryDelete = true
    @State private var newSlot: NewSlotSheet.Request?
    @State private var editSlot: EditSlotSheet.Request?
    @State private var showNewLibrary = false
    @State private var newSlotId: UUID?
    @State private var showSettings = false

    // Borrar con deshacer
    @State private var undo: UndoNotice?
    @State private var undoTask: Task<Void, Never>?

    // Bibliotecas
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
                        Text("Arrastrá para reordenar o llevar un slot a otra biblioteca · Tocá una tarjeta para editarla · ✕ vacía el slot")
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
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 64) }
        }
        .padding(.horizontal, SlotsSpace.m)
        .padding(.top, 4)
        .background(SlotsColor.papel.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            VStack(spacing: SlotsSpace.s) {
                if let undo { undoPill(undo) }
                libraryBar
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
        .sheet(item: $renameRequest) { request in renameSheet(for: request) }
        .sheet(item: $deleting) { library in
            ConfirmDeleteSheet(
                title: "¿Eliminar «\(library.name)»?",
                message: "Se borran también todos sus slots, en todos tus dispositivos.",
                confirmTitle: "Eliminar biblioteca"
            ) {
                withAnimation(.easeInOut(duration: 0.15)) { _ = store.deleteLibrary(id: library.id) }
            }
        }
        .onOpenURL { url in
            // Widget: abre en la biblioteca configurada.
            guard url.scheme == "hotslot", url.host == "library", let id = UUID(uuidString: url.lastPathComponent),
                  store.workspace.libraries.contains(where: { $0.id == id }) else { return }
            withAnimation(.easeInOut(duration: 0.15)) { store.setActiveLibrary(id: id) }
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
                .contentShape(Rectangle())
                // Tocar el título renombra la biblioteca.
                .onTapGesture { if !isEditing, let library = activeLibrary { renameRequest = .library(library) } }
                .accessibilityAction(named: "Renombrar biblioteca") { if let library = activeLibrary { renameRequest = .library(library) } }
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
            onRename: { renameRequest = .library($0) },
            onDelete: { library in
                if confirmLibraryDelete {
                    deleting = library
                } else {
                    withAnimation(.easeInOut(duration: 0.15)) { _ = store.deleteLibrary(id: library.id) }
                }
            },
            highlightedId: hoverPill,
            onSlotHover: { slotHoverPill($0) },
            onSlotDrop: { slotDroppedOnPill($0) },
            onMove: { id, index in
                withAnimation(.easeOut(duration: 0.2)) { store.moveLibrary(id: id, toIndex: index) }
            }
        )
    }

    // MARK: - Grilla

    private func cardView(_ slot: SlotRecord, copied: Bool = false, handle: Bool = false, cross: Bool = false) -> some View {
        SlotCardView(
            slot: slot,
            isCopied: copied,
            showsHandle: handle,
            showsCross: cross,
            isDropTarget: dropTargetId == slot.id && draggingId != slot.id
        )
    }

    /// Id con el que la card «Nuevo slot» participa de los arrastres.
    private static let newTileId = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!

    private var grid: some View {
        SlotGridLayout {
            ForEach(slots) { slot in slotCell(slot) }
            newSlotTile
        }
        .coordinateSpace(name: Self.gridSpace)
        .overlay(alignment: .topLeading) { swapOverlay }
        .onDrop(of: [.slotsSlotDrag], delegate: GridDropDelegate(
            onUpdate: { location in dragUpdated(location) },
            onExit: { dropTargetId = nil },
            onDrop: { location in dropped(at: location) }
        ))
    }

    @ViewBuilder private func slotCell(_ slot: SlotRecord) -> some View {
        let isCopied = copiedSlotId == slot.id
        let hiddenBySwap = swapAnim.map { $0.landed == slot.id || $0.other == slot.id } ?? false
        let hasContent = slot.clipContent() != nil
        let removable = model.canRemove(slot)
        Button { tap(slot) } label: {
            cardView(slot, copied: isCopied, handle: isEditing, cross: isEditing && (hasContent || removable))
        }
        .buttonStyle(SlotCardButtonStyle())
        // Lápiz (modo normal): abre el editor sin pasar por el menú.
        .overlay(alignment: .topTrailing) {
            if !isEditing && hasContent && !isCopied {
                Button { editSlot = .init(slotId: slot.id) } label: {
                    Color.clear.frame(width: 48, height: 48).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            }
        }
        // Cruz (modo Editar): vacía el slot, o lo elimina si ya está vacío y pasa del quinto.
        .overlay(alignment: .topLeading) {
            if isEditing && (hasContent || removable) {
                Button { delete(slot.id) } label: {
                    Color.clear.frame(width: 48, height: 48).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hasContent ? "Vaciar slot" : "Eliminar slot")
            }
        }
        .contextMenu { if !isEditing { menu(for: slot) } }
        .accessibilityAction(named: "Editar") { if hasContent { editSlot = .init(slotId: slot.id) } }
        .accessibilityAction(named: hasContent ? "Vaciar" : "Eliminar") { delete(slot.id) }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.gridSpace)) } action: { cardFrames[slot.id] = $0 }
        .onDrag {
            draggingId = slot.id
            dragCursor = nil
            dragGrab = nil
            let provider = NSItemProvider()
            // Solo sirve dentro de Slots: en otra app no suelta nada.
            provider.registerDataRepresentation(forTypeIdentifier: UTType.slotsSlotDrag.identifier, visibility: .ownProcess) { done in
                done(Data(slot.id.uuidString.utf8), nil)
                return nil
            }
            return provider
        } preview: {
            // La card levantada la dibuja el sistema: sigue al dedo en toda la pantalla, también sobre las bibliotecas.
            let frame = cardFrames[slot.id]
            cardView(slot)
                .frame(width: frame?.width ?? 170, height: frame?.height ?? 166)
                .clipShape(RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous))
        }
        .slotRowSpan(SlotCardView.rowSpan(for: slot))
        .scaleEffect(isCopied ? 0.97 : (newSlotId == slot.id ? 0.9 : 1))
        .shadow(color: Color(slotsHex: 0xE2470F).opacity(isCopied ? 0.35 : 0), radius: 15, y: 14)
        .opacity(hiddenBySwap || newSlotId == slot.id ? 0
                 : (copiedSlotId != nil && !isCopied ? 0.55 : 1))
        .zIndex(isCopied ? 1 : 0)
    }

    /// Card punteada al final de la grilla, igual que en el Mac: crea un slot al final o recibe uno arrastrado.
    private var newSlotTile: some View {
        let isTarget = dropTargetId == Self.newTileId && draggingId != nil
        return Button { createSlotAtEnd() } label: {
            VStack(spacing: SlotsSpace.s) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                Text(isTarget ? "Soltá para crear el slot" : "Nuevo slot")
                    .slotsText(15)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(isTarget ? SlotsColor.naranja : SlotsColor.textoSecundario)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous)
                    .strokeBorder(isTarget ? SlotsColor.naranja : SlotsColor.bordePunteado,
                                  style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            .contentShape(RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous))
        }
        .buttonStyle(SlotCardButtonStyle())
        .accessibilityLabel("Nuevo slot")
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.gridSpace)) } action: { cardFrames[Self.newTileId] = $0 }
    }

    /// Igual que el Mac: agrega un slot vacío al final y pide su nombre.
    private func createSlotAtEnd() {
        guard let library = activeLibrary,
              let order = store.addSlot(toLibraryId: library.id),
              let record = store.slots(for: library.id).first(where: { $0.order == order }) else { return }
        highlightNew(record.id)
        renameRequest = .slot(record, isNew: true)
    }

    private static let gridSpace = "slotsGrid"

    /// Solo cuentan las cards de la biblioteca que se ve: al cambiar de biblioteca quedan marcos viejos.
    private func cardId(at point: CGPoint) -> UUID? {
        let visible = Set(slots.map(\.id)).union([Self.newTileId])
        return cardFrames.first(where: { visible.contains($0.key) && $0.value.contains(point) })?.key
    }

    private func dragUpdated(_ location: CGPoint) {
        guard let source = draggingId else { return }
        if dragGrab == nil, let frame = cardFrames[source] {
            dragGrab = CGPoint(
                x: min(max(location.x - frame.minX, 0), frame.width),
                y: min(max(location.y - frame.minY, 0), frame.height)
            )
        }
        dragCursor = location
        let target = cardId(at: location)
        dropTargetId = target == source ? nil : target
    }

    /// Suelta sobre la grilla. Misma biblioteca: intercambia (o manda al final si es «Nuevo slot»).
    /// Otra biblioteca: el slot pasa a la posición donde lo soltaste.
    private func dropped(at location: CGPoint) -> Bool {
        defer {
            draggingId = nil
            dropTargetId = nil
            dragCursor = nil
            dragGrab = nil
            slotHoverPill(nil)
        }
        guard let source = draggingId, let sourceSlot = store.slot(id: source) else { return false }
        let target = cardId(at: location)
        let activeId = store.workspace.activeLibraryId
        let sameLibrary = sourceSlot.libraryId == activeId

        if target == Self.newTileId {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                if sameLibrary { model.moveToEnd(slotId: source) } else { model.move(slotId: source, toLibraryId: activeId) }
            }
            return true
        }
        guard let target, target != source, let targetSlot = store.slot(id: target) else {
            // Soltó en un hueco de otra biblioteca: va al final de esa biblioteca.
            if !sameLibrary {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { model.move(slotId: source, toLibraryId: activeId) }
                return true
            }
            return false
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard sameLibrary else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { model.transfer(slotId: source, onto: targetSlot.id) }
            return true
        }
        guard let sourceFrame = cardFrames[source], let targetFrame = cardFrames[target] else { return false }
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

    /// Arrastrando un slot sobre una pill: a los 0,6 s se muestra esa biblioteca para soltarlo ahí.
    private func slotHoverPill(_ id: UUID?) {
        hoverTask?.cancel()
        hoverPill = id
        guard let id, id != store.workspace.activeLibraryId else { return }
        hoverTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) { store.setActiveLibrary(id: id) }
        }
    }

    private func slotDroppedOnPill(_ libraryId: UUID) {
        defer {
            draggingId = nil
            dropTargetId = nil
            dragCursor = nil
            slotHoverPill(nil)
        }
        guard let source = draggingId, let slot = store.slot(id: source), slot.libraryId != libraryId else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.2)) { model.move(slotId: source, toLibraryId: libraryId) }
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
        if slot.clipContent() != nil {
            Button("Editar", systemImage: "pencil") {
                editSlot = .init(slotId: slot.id)
            }
            Button("Renombrar", systemImage: "textformat") { beginRename(slot) }
            Menu("Color de fondo", systemImage: "paintpalette") {
                backgroundButton("Predeterminado (Piedra)", hex: nil, slot: slot)
                backgroundButton("Degradé naranja (marca)", hex: SlotsPalette.brandGradientAsset, slot: slot)
                ForEach(SlotsPalette.slotBackgrounds, id: \.hex) { entry in
                    backgroundButton(entry.name, hex: SlotsPalette.normalizedHex(entry.hex), slot: slot)
                }
            }
            if clipboardAvailable {
                Button("Reemplazar con el portapapeles", systemImage: "arrow.left.arrow.right") { replace(slot) }
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
            Button("Renombrar", systemImage: "textformat") { beginRename(slot) }
            if clipboardAvailable {
                Button("Pegar portapapeles", systemImage: "doc.on.clipboard") { replace(slot) }
            }
            if model.canRemove(slot) {
                Divider()
                Button("Eliminar slot", systemImage: "trash", role: .destructive) { delete(slot.id) }
            }
        }
    }

    private func beginRename(_ slot: SlotRecord) { renameRequest = .slot(slot, isNew: false) }

    @ViewBuilder private func renameSheet(for request: RenameRequest) -> some View {
        switch request {
        case .library(let library):
            RenameSheet(
                title: "Renombrar biblioteca",
                label: "Nombre",
                initialName: library.name,
                error: { model.isLibraryNameTaken($0, excluding: library.id) ? "Ya tenés una biblioteca con ese nombre." : nil },
                onSave: { store.renameLibrary(id: library.id, name: $0) }
            )
        case .slot(let slot, let isNew):
            RenameSheet(
                title: isNew ? "Nuevo slot" : "Renombrar slot",
                label: "Nombre del slot",
                initialName: isNew ? "" : (SlotCardText.customTitle(slot) ?? (slot.clipContent() == nil ? "" : SlotCardText.title(slot))),
                onSave: { name in store.updateSlot(id: slot.id) { $0.title = name } },
                onCancel: {
                    // Un slot nuevo sin nombre ni contenido se descarta, como Esc en el Mac.
                    if isNew, let current = store.slot(id: slot.id), current.clipContent() == nil {
                        withAnimation(.easeOut(duration: 0.2)) { _ = store.removeSlot(libraryId: current.libraryId, order: current.order) }
                    }
                }
            )
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
