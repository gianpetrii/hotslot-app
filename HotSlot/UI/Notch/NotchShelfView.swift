import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers

private let shelfSpace = "notchShelf"

// MARK: - Hover por posición del mouse

/// El panel de la barra no toma foco y SwiftUI no le entrega `onHover`.
/// El controlador publica la posición real del mouse y cada elemento decide si está debajo.
private struct PointerHover: ViewModifier {
    let pointer: NotchShelfPointer
    @Binding var isHovering: Bool

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geo in
                Color.clear
                    .onChange(of: pointer.location) { _, point in
                        let inside = point.map { geo.frame(in: .named(shelfSpace)).contains($0) } ?? false
                        if inside != isHovering { isHovering = inside }
                    }
            }
        }
    }
}

private extension View {
    func pointerHover(_ pointer: NotchShelfPointer, isHovering: Binding<Bool>) -> some View {
        modifier(PointerHover(pointer: pointer, isHovering: isHovering))
    }
}

// MARK: - Contenedor principal (el panel acostado)

struct NotchShelfView: View {
    @Bindable var appState: AppState
    let pointer: NotchShelfPointer
    let onActivateSlot: (Int) -> Void
    let onDropFile: (Int, URL) -> Void
    let onOpenPanel: () -> Void
    let onRenameLibrary: (Library) -> Void
    let onDeleteLibrary: (Library) -> Void
    let onNewLibrary: () -> Void
    let onNewSlot: () -> Void

    @State private var isOpenPanelHovering = false
    @State private var libraryDrag: NotchLibraryDrag?
    /// Posiciones de las pills tomadas al empezar a arrastrar (durante el arrastre las pills se mueven).
    @State private var dragStartFrames: [UUID: CGRect] = [:]
    @State private var latestPillFrames: [UUID: CGRect] = [:]
    @State private var trashFrame: CGRect = .zero
    @State private var page = 0
    @State private var pageDirection = 1

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: NotchShelfMetrics.shelfCorner, style: .continuous)

        VStack(alignment: .leading, spacing: NotchShelfMetrics.sectionGap) {
            // Cada página trae hasta 5 slots; al cambiar de página la fila entra desde el lado hacia donde vas.
            HStack(spacing: NotchShelfMetrics.gap) {
            ZStack(alignment: .leading) {
                HStack(spacing: NotchShelfMetrics.gap) {
                    ForEach(pageEntries) { entry in
                        switch entry {
                        case .newSlot:
                            NotchNewSlotTile(pointer: pointer, action: onNewSlot)
                                .transition(.slotArrival)
                        case .slot(let slot):
                        NotchShelfTile(
                            slot: slot,
                            pointer: pointer,
                            onActivate: { onActivateSlot(slot.index) },
                            onDropFile: { url in onDropFile(slot.index, url) },
                            onClear: { withAnimation(.easeInOut(duration: 0.22)) { appState.slotStore.clearSlot(index: slot.index) } },
                            onDelete: slot.index > SlotStore.slotCount && slot.content == nil
                                ? { withAnimation(.easeInOut(duration: 0.22)) { appState.deleteSlot(index: slot.index) } }
                                : nil
                        )
                        .slotArrival(appState.slotArrival?.index == slot.index)
                        .transition(.slotArrival)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.78), value: pageEntries.map(\.id))
                }
                .id(page)
                .transition(.asymmetric(
                    insertion: .modifier(active: ShiftFade(y: CGFloat(pageDirection) * 48, opacity: 0), identity: ShiftFade(y: 0, opacity: 1)),
                    removal: .modifier(active: ShiftFade(y: CGFloat(-pageDirection) * 48, opacity: 0), identity: ShiftFade(y: 0, opacity: 1))
                ))
            }
            .frame(width: NotchShelfMetrics.tileWidth * 5 + NotchShelfMetrics.gap * 4, height: NotchShelfMetrics.tileHeight, alignment: .leading)
            .clipped()

            // Columna fija: ocupa su lugar siempre para que la barra no cambie de ancho al aparecer una segunda página.
            Group { if pageCount > 1 { pager } else { Color.clear } }
                .frame(width: NotchShelfMetrics.pagerWidth, height: NotchShelfMetrics.tileHeight)
            }

            HStack(spacing: SlotsSpace.m) {
                ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SlotsSpace.s) {
                        ForEach(Array(libraries.enumerated()), id: \.element.id) { position, library in
                            libraryPill(library, at: position)
                                .id(library.id)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 6)
                }
                // El recorte horizontal evita que una pill larga tape los botones; el vertical deja lugar al realce.
                .padding(.vertical, -6)
                .onChange(of: activeId) { _, id in
                    withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .center) }
                }
                .onAppear { proxy.scrollTo(activeId, anchor: .center) }
                }

                NotchPageButton(systemImage: "plus", isEnabled: libraryDrag == nil, pointer: pointer, action: onNewLibrary)
                    .help("Nueva biblioteca")

                openPanelButton
            }
            .frame(height: NotchShelfMetrics.libraryHeight)
            .onPreferenceChange(NotchPillFramesKey.self) { latestPillFrames = $0 }
        }
        .padding(.horizontal, NotchShelfMetrics.pad)
        .padding(.vertical, NotchShelfMetrics.padVertical)
        .frame(width: NotchShelfMetrics.contentWidth, height: NotchShelfMetrics.contentHeight)
        // Mismo vidrio, borde y sombra que `PanelChrome`.
        .background {
            ZStack {
                SlotsColor.vidrioTinte
                VisualEffectBackground(
                    material: .hudWindow,
                    blendingMode: .behindWindow,
                    cornerRadius: NotchShelfMetrics.shelfCorner
                )
                .opacity(0.85)
            }
            .clipShape(shape)
            .shadow(color: Color(slotsHex: 0x462D14).opacity(0.22), radius: 30, y: 12)
        }
        .overlay {
            shape.strokeBorder(Color.white.opacity(0.75), lineWidth: 1)
        }
        // La ventana de AppKit es más grande: el margen aloja la sombra (y el tacho al arrastrar una biblioteca).
        .padding(NotchShelfMetrics.shadowPad)
        .frame(width: NotchShelfMetrics.panelWidth, height: NotchShelfMetrics.panelHeight, alignment: .top)
        .overlay(alignment: .bottom) {
            if libraryDrag != nil, libraryDrag?.settling != true {
                // Debajo de la barra, con aire: la ventana tiene una franja extra para él.
                libraryTrash
                    .padding(.bottom, NotchShelfMetrics.shadowPad / 2 + 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .overlay(alignment: .topLeading) { floatingLibraryPill }
        .coordinateSpace(name: shelfSpace)
        .ignoresSafeArea()
        .onChange(of: libraryDrag?.id) { _, id in appState.notchLibraryDragging = id != nil }
        .onChange(of: appState.slotScrollTarget) { _, target in
            // Un slot recién creado: la barra va a la página donde quedó.
            guard let target else { return }
            goToPage((target.index - 1) / NotchShelfMetrics.pageSize)
        }
        .onChange(of: appState.notchOpenCount) { _, _ in page = 0 }
        .onChange(of: activeId) { _, _ in goToPage(0) }
        .onChange(of: pageCount) { _, count in if page >= count { page = max(0, count - 1) } }
        .onChange(of: appState.notchPageRequest) { _, request in
            guard let request else { return }
            goToPage(page + request)
            appState.notchPageRequest = nil
        }
    }

    // MARK: Páginas

    private var pageCount: Int {
        max(1, (appState.slotStore.totalSlotCount + 1 + NotchShelfMetrics.pageSize - 1) / NotchShelfMetrics.pageSize)
    }

    /// Los slots de la página; al final de todos va el tile «Nuevo slot».
    private var pageEntries: [PageEntry] {
        let start = page * NotchShelfMetrics.pageSize
        var entries: [PageEntry] = appState.slotStore.allSlots
            .filter { $0.index > start && $0.index <= start + NotchShelfMetrics.pageSize }
            .map { .slot($0) }
        if entries.count < NotchShelfMetrics.pageSize, start + entries.count == appState.slotStore.totalSlotCount {
            entries.append(.newSlot)
        }
        return entries
    }

    private func goToPage(_ target: Int) {
        let clamped = min(max(target, 0), pageCount - 1)
        guard clamped != page else { return }
        pageDirection = clamped > page ? 1 : -1
        withAnimation(.easeInOut(duration: 0.22)) { page = clamped }
    }

    /// Flechas y «1/3»: mismo estilo que el botón de abrir el panel.
    private var pager: some View {
        VStack(spacing: 4) {
            NotchPageButton(systemImage: "chevron.up", isEnabled: page > 0, pointer: pointer, size: NotchShelfMetrics.pagerWidth) { goToPage(page - 1) }
            Text("\(page + 1)/\(pageCount)")
                .font(SlotsFont.etiqueta)
                .foregroundStyle(SlotsColor.textoSecundario)
                .monospacedDigit()
                .contentTransition(.numericText())
            NotchPageButton(systemImage: "chevron.down", isEnabled: page < pageCount - 1, pointer: pointer, size: NotchShelfMetrics.pagerWidth) { goToPage(page + 1) }
        }
    }

    // MARK: Arrastre de bibliotecas

    private func libraryPill(_ library: Library, at position: Int) -> some View {
        NotchShelfLibraryPill(
            name: library.name,
            count: appState.libraryWorkspace.filledSlotCount(in: library.id),
            isActive: library.id == activeId,
            pointer: pointer,
            onTap: {
                withAnimation(.easeInOut(duration: 0.22)) {
                    appState.switchLibrary(to: library.id)
                }
            },
            onRename: { onRenameLibrary(library) },
            onDelete: libraries.count > 1 ? { onDeleteLibrary(library) } : nil,
            onMoveLeft: position > 0 ? { moveLibrary(library, to: position - 1) } : nil,
            onMoveRight: position < libraries.count - 1 ? { moveLibrary(library, to: position + 1) } : nil
        )
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: NotchPillFramesKey.self, value: [library.id: geo.frame(in: .named(shelfSpace))])
            }
        }
        // La pill que arrastrás se dibuja aparte (flota libre sobre la barra); acá queda su huella.
        .opacity(libraryDrag?.id == library.id ? 0.28 : 1)
        .offset(x: dragOffset(for: library, at: position))
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: libraryDrag?.insert)
        .gesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .named(shelfSpace))
                .onChanged { value in updateLibraryDrag(library, value: value) }
                .onEnded { _ in finishLibraryDrag(library) }
        )
    }

    private func dragOffset(for library: Library, at position: Int) -> CGFloat {
        guard let drag = libraryDrag, library.id != drag.id else { return 0 }
        guard !drag.settling, let width = dragStartFrames[drag.id]?.width else { return 0 }
        let shift = width + SlotsSpace.s
        if drag.insert > drag.origin, position > drag.origin, position <= drag.insert { return -shift }
        if drag.insert < drag.origin, position >= drag.insert, position < drag.origin { return shift }
        return 0
    }

    private func updateLibraryDrag(_ library: Library, value: DragGesture.Value) {
        if libraryDrag == nil {
            guard let origin = libraries.firstIndex(where: { $0.id == library.id }) else { return }
            dragStartFrames = latestPillFrames
            libraryDrag = NotchLibraryDrag(id: library.id, origin: origin, insert: origin, translation: .zero, location: value.location)
        }
        guard var drag = libraryDrag, drag.id == library.id, !drag.settling,
              let startFrame = dragStartFrames[library.id] else { return }
        drag.translation = value.translation
        drag.location = value.location
        // Lejos de la fila (camino al tacho) la pill no reordena: vuelve a su lugar de origen.
        let nearRow = abs(value.location.y - startFrame.midY) < NotchShelfMetrics.libraryHeight
        if nearRow {
            let center = startFrame.midX + value.translation.width
            let others = libraries.filter { $0.id != library.id }
            drag.insert = others.filter { (dragStartFrames[$0.id]?.midX ?? .infinity) < center }.count
        } else {
            drag.insert = drag.origin
        }
        libraryDrag = drag
    }

    private func finishLibraryDrag(_ library: Library) {
        guard let drag = libraryDrag, drag.id == library.id, !drag.settling,
              let startFrame = dragStartFrames[library.id] else { return }
        if trashFrame.insetBy(dx: -10, dy: -10).contains(drag.location) {
            libraryDrag = nil
            onDeleteLibrary(library)
            return
        }
        // Aterriza en su lugar (el nuevo si cambió el orden).
        var delta: CGFloat = 0
        if drag.insert != drag.origin {
            let range = drag.insert > drag.origin ? (drag.origin + 1)...drag.insert : drag.insert...(drag.origin - 1)
            let shifted = range.reduce(CGFloat(0)) { total, position in
                total + (dragStartFrames[libraries[position].id]?.width ?? 0) + SlotsSpace.s
            }
            delta = drag.insert > drag.origin ? shifted : -shifted
        }
        var settling = drag
        settling.settling = true
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            if drag.insert != drag.origin { appState.moveLibrary(id: library.id, toIndex: drag.insert) }
            libraryDrag = settling
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            libraryDrag?.translation = CGSize(width: delta, height: 0)
        }
        _ = startFrame
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            if libraryDrag?.settling == true { libraryDrag = nil }
        }
    }

    /// La pill arrastrada: sigue al cursor en cualquier dirección, por encima de la barra.
    @ViewBuilder
    private var floatingLibraryPill: some View {
        if let drag = libraryDrag, let frame = dragStartFrames[drag.id],
           let library = libraries.first(where: { $0.id == drag.id }) {
            LibraryPillLabel(
                name: library.name,
                count: appState.libraryWorkspace.filledSlotCount(in: library.id),
                isActive: library.id == activeId
            )
            .frame(width: frame.width, height: frame.height)
            .shadow(color: .black.opacity(0.24), radius: 10, y: 5)
            .offset(x: frame.minX + drag.translation.width, y: frame.minY + drag.translation.height)
            .allowsHitTesting(false)
        }
    }

    /// Mientras se arrastra una pill, el tacho ocupa el lugar del botón de abrir el panel.
    private var libraryTrash: some View {
        let targeted = libraryDrag.map { trashFrame.insetBy(dx: -10, dy: -10).contains($0.location) } ?? false
        return Image(systemName: targeted ? "trash.fill" : "trash")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(targeted ? SlotsColor.naranja : SlotsColor.textoSecundario)
            .frame(width: 40, height: 40)
            .background {
                Circle()
                    .fill(targeted ? SlotsColor.cardOscura : Color.white.opacity(0.85))
                    .overlay { Circle().strokeBorder(targeted ? SlotsColor.naranja : Color.black.opacity(0.12), lineWidth: targeted ? 2 : 1) }
            }
            .scaleEffect(targeted ? 1.2 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.66), value: targeted)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { trashFrame = geo.frame(in: .named(shelfSpace)) }
                        .onDisappear { trashFrame = .zero }
                }
            }
    }

    private func moveLibrary(_ library: Library, to index: Int) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            appState.moveLibrary(id: library.id, toIndex: index)
        }
    }

    // MARK: Datos

    private var libraries: [Library] {
        appState.libraryWorkspace.workspace.libraries.sorted { $0.order < $1.order }
    }

    private var activeId: UUID {
        appState.libraryWorkspace.workspace.activeLibraryId
    }

    // MARK: Abrir panel (mismo estilo que el «+» de `PanelLibraryBar`)

    private var openPanelButton: some View {
        Button(action: onOpenPanel) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SlotsColor.textoSecundario)
                .frame(width: SlotsRadius.controlAlto, height: SlotsRadius.controlAlto)
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .overlay { Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 1) }
                }
        }
        .buttonStyle(.plain)
        .slotsHoverLift(isOpenPanelHovering, scales: true)
        .animation(.easeOut(duration: 0.16), value: isOpenPanelHovering)
        .pointerHover(pointer, isHovering: $isOpenPanelHovering)
    }
}

/// Desplazamiento + fundido para el cambio de página.
private struct ShiftFade: ViewModifier {
    let y: CGFloat
    let opacity: Double
    func body(content: Content) -> some View {
        content.offset(y: y).opacity(opacity)
    }
}

private struct NotchPageButton: View {
    let systemImage: String
    let isEnabled: Bool
    let pointer: NotchShelfPointer
    var size: CGFloat = SlotsRadius.controlAlto
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SlotsColor.textoSecundario)
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .overlay { Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 1) }
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .slotsHoverLift(isHovering && isEnabled, scales: true)
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .animation(.easeOut(duration: 0.16), value: isEnabled)
        .pointerHover(pointer, isHovering: $isHovering)
    }
}

private enum PageEntry: Identifiable {
    case slot(Slot)
    case newSlot

    var id: String {
        switch self {
        case .slot(let slot): "slot-\(slot.index)"
        case .newSlot: "nuevo"
        }
    }
}

/// «Nuevo slot» al final de la lista: un clic guarda el portapapeles en un slot nuevo.
private struct NotchNewSlotTile: View {
    let pointer: NotchShelfPointer
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                Text("Nuevo slot")
                    .font(.custom("InterTight-Medium", size: 14))
            }
            .foregroundStyle(SlotsColor.textoSecundario)
            .frame(width: NotchShelfMetrics.tileWidth, height: NotchShelfMetrics.tileHeight)
            .background {
                RoundedRectangle(cornerRadius: NotchShelfMetrics.tileCorner, style: .continuous)
                    .fill(Color.white.opacity(isHovering ? 0.6 : 0.28))
            }
            .overlay {
                RoundedRectangle(cornerRadius: NotchShelfMetrics.tileCorner, style: .continuous)
                    .strokeBorder(Color.black.opacity(isHovering ? 0.5 : 0.24), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
            }
            .contentShape(RoundedRectangle(cornerRadius: NotchShelfMetrics.tileCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .slotsHoverLift(isHovering, scales: true)
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .pointerHover(pointer, isHovering: $isHovering)
        .help("Guarda el portapapeles en un slot nuevo")
    }
}

// MARK: - Pill de biblioteca

private struct NotchLibraryDrag {
    let id: UUID
    let origin: Int
    var insert: Int
    var translation: CGSize
    var location: CGPoint
    /// Ya se soltó: la pill flotante aterriza en su lugar.
    var settling = false
}

private struct NotchPillFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct NotchShelfLibraryPill: View {
    let name: String
    let count: Int
    let isActive: Bool
    let pointer: NotchShelfPointer
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: (() -> Void)?
    let onMoveLeft: (() -> Void)?
    let onMoveRight: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        LibraryPillLabel(name: name, count: count, isActive: isActive)
            .slotsHoverLift(isHovering && !isActive, scales: true)
            .animation(.easeOut(duration: 0.16), value: isHovering)
            .pointerHover(pointer, isHovering: $isHovering)
            .contentShape(Capsule(style: .continuous))
            .onTapGesture {
                guard !isActive else { return }
                onTap()
            }
            // Mismas acciones que el menú de la pill en el panel; reordenar con «Mover» en lugar de arrastrar.
            .contextMenu {
                Button("Renombrar…", action: onRename)
                if let onMoveLeft { Button("Mover a la izquierda", action: onMoveLeft) }
                if let onMoveRight { Button("Mover a la derecha", action: onMoveRight) }
                if let onDelete {
                    Divider()
                    Button("Eliminar «\(name)»…", role: .destructive, action: onDelete)
                }
            }
    }
}

// MARK: - Tile de slot (misma lógica visual que `SlotCardView`)

private struct NotchShelfTile: View {
    let slot: Slot
    let pointer: NotchShelfPointer
    let onActivate: () -> Void
    let onDropFile: (URL) -> Void
    let onClear: () -> Void
    var onDelete: (() -> Void)?

    @State private var isHovering = false
    @State private var isDropTarget = false
    @State private var pressScale: CGFloat = 1

    private var radius: CGFloat { NotchShelfMetrics.tileCorner }

    var body: some View {
        Button(action: press) {
            ZStack(alignment: .topLeading) {
                chrome

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        // Sitio de la cruz (vive encima del botón): sin texto de tipo ni tamaño.
                        Color.clear.frame(width: HotSlotDesign.slotHeaderChipHeight, height: HotSlotDesign.slotHeaderChipHeight)
                        Spacer(minLength: 0)
                        // Solo lectura: enseña el atajo. Se edita desde el panel.
                        // Sin sombra sobre la pastilla: la sombra del texto la dejaba sucia sobre imágenes y colores.
                        if let shortcutName {
                            SlotHandoffShortcutChip(
                                name: shortcutName,
                                ink: SlotsColor.textoSecundario,
                                plate: prefersLight ? Color.white.opacity(0.92) : SlotsColor.teclaFondo
                            )
                            .layoutPriority(1)
                        }
                    }

                    if case .file = slot.content, let content = slot.content {
                        FileClipIconView(content: content, side: 24)
                    } else if let preview = SlotCardCopy.contentBodyPreview(for: slot), !isImage {
                        Text(preview)
                            .font(SlotsFont.etiqueta)
                            .foregroundStyle(prefersLight ? Color.white : SlotsColor.tinta)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .modifier(SlotReadableText(onDark: prefersLight))
                    } else if !hasContent {
                        // Sin botón de guardar: el clic en un slot vacío guarda el portapapeles.
                        Text("Clic para guardar el portapapeles")
                            .font(SlotsFont.etiqueta)
                            .foregroundStyle(SlotsColor.textoSecundario)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)

                    Text(SlotCardCopy.visibleCardTitle(for: slot))
                        .font(.custom("InterTight-Medium", size: 14))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .modifier(SlotReadableText(onDark: prefersLight))
                }
                .padding(SlotsSpace.s + 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background { scrims }
            }
            .frame(width: NotchShelfMetrics.tileWidth, height: NotchShelfMetrics.tileHeight)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) { headerAction }
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(SlotsColor.naranja, lineWidth: 2)
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTarget) { providers in
            guard let provider = providers.first(where: {
                $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            }) else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, url.isFileURL else { return }
                DispatchQueue.main.async { onDropFile(url) }
            }
            return true
        }
        .animation(.easeOut(duration: 0.12), value: isDropTarget)
        .scaleEffect(pressScale)
        .slotsHoverLift((isHovering || isDropTarget) && (hasContent || isDropTarget), scales: true)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isHovering)
        .pointerHover(pointer, isHovering: $isHovering)
    }

    // MARK: Cruz / tacho (como en la card del panel)

    @ViewBuilder
    private var headerAction: some View {
        let plate = prefersLight ? Color.white.opacity(0.92) : SlotsColor.teclaFondo
        if isHovering, let onDelete {
            Button(action: onDelete) {
                SlotHeaderActionChip(systemImage: "trash", foreground: SlotsColor.textoSecundario, plate: plate)
            }
            .buttonStyle(.plain)
            .padding(SlotsSpace.s + 2)
            .transition(.opacity.combined(with: .scale(scale: 0.88)))
        } else if isHovering, hasContent {
            Button(action: onClear) {
                SlotHeaderActionChip(systemImage: "xmark", foreground: SlotsColor.textoSecundario, plate: plate)
            }
            .buttonStyle(.plain)
            .padding(SlotsSpace.s + 2)
            .transition(.opacity.combined(with: .scale(scale: 0.88)))
        }
    }

    // MARK: Acción

    private func press() {
        withAnimation(.easeOut(duration: 0.07)) { pressScale = 0.92 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pressScale = 1 }
            onActivate()
        }
    }

    // MARK: Propiedades del slot

    /// Atajo visible: los primeros 5 siempre; del 6 en adelante solo si el usuario se lo asignó.
    private var shortcutName: KeyboardShortcuts.Name? {
        let name = hasContent
            ? KeyboardShortcuts.Name.pasteSlotName(slot.index)
            : KeyboardShortcuts.Name.copyToSlotName(slot.index)
        if slot.index <= SlotStore.slotCount { return name }
        return KeyboardShortcuts.getShortcut(for: name) == nil ? nil : name
    }

    private var hasContent: Bool { slot.content != nil }

    private var isImage: Bool {
        if case .image = slot.content { return true }
        return false
    }

    private var isDarkCard: Bool {
        guard case .text(let string) = slot.content else { return false }
        return SlotCardCopy.isHexColor(string.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var backgroundHex: String? { SlotsPalette.storedBackgroundHex(slot.cardBackgroundHex) }

    private var prefersLight: Bool {
        guard hasContent else { return false }
        if isImage { return true }
        if SlotsPalette.prefersLightContent(hexString: backgroundHex) { return true }
        if isDarkCard, backgroundHex == nil { return true }
        return false
    }

    private var titleColor: Color {
        if prefersLight { return .white }
        return hasContent || slot.index != 5 ? SlotsColor.tinta : SlotsColor.textoSecundario
    }

    // MARK: Fondo

    private var chromeFill: Color {
        if !hasContent { return Color.white.opacity(0.28) }
        if let custom = SlotsPalette.color(hexString: backgroundHex) { return custom }
        if isDarkCard { return SlotsColor.cardOscura }
        return SlotsColor.piedra
    }

    private var chrome: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(chromeFill)

            if hasContent, SlotsPalette.isBrandGradient(backgroundHex) {
                Image("DegradeNaranja")
                    .resizable()
                    .scaledToFill()
                    .frame(width: NotchShelfMetrics.tileWidth, height: NotchShelfMetrics.tileHeight)
                    .clipped()
            }

            if hasContent, isImage, case .image(let fileName) = slot.content {
                ClipThumbnailView(fileName: fileName, style: .slot)
            }

            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    Color.black.opacity(hasContent ? 0 : 0.22),
                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                )
        }
        .frame(width: NotchShelfMetrics.tileWidth, height: NotchShelfMetrics.tileHeight)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .animation(.easeInOut(duration: 0.28), value: chromeFill)
    }

    /// Degradé e imagen: velo oscuro arriba y abajo para que el texto blanco se lea.
    @ViewBuilder
    private var scrims: some View {
        if hasContent, SlotsPalette.isBrandGradient(backgroundHex) || isImage {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0.42), Color.black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 28)
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 48)
            }
            .allowsHitTesting(false)
        }
    }
}
