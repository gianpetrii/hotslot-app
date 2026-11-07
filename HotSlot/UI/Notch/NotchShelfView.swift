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

    @State private var isOpenPanelHovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: NotchShelfMetrics.shelfCorner, style: .continuous)

        VStack(alignment: .leading, spacing: NotchShelfMetrics.sectionGap) {
            HStack(spacing: NotchShelfMetrics.gap) {
                ForEach(appState.slotStore.slots) { slot in
                    NotchShelfTile(
                        slot: slot,
                        pointer: pointer,
                        onActivate: { onActivateSlot(slot.index) },
                        onDropFile: { url in onDropFile(slot.index, url) }
                    )
                }
            }

            HStack(spacing: SlotsSpace.m) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SlotsSpace.s) {
                        ForEach(libraries) { library in
                            NotchShelfLibraryPill(
                                name: library.name,
                                count: appState.libraryWorkspace.filledSlotCount(in: library.id),
                                isActive: library.id == activeId,
                                pointer: pointer
                            ) {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    appState.switchLibrary(to: library.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()

                openPanelButton
            }
            .frame(height: NotchShelfMetrics.libraryHeight)
        }
        .padding(NotchShelfMetrics.pad)
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
        // La ventana de AppKit es más grande: el margen aloja la sombra.
        .padding(NotchShelfMetrics.shadowPad)
        .frame(width: NotchShelfMetrics.panelWidth, height: NotchShelfMetrics.panelHeight)
        .coordinateSpace(name: shelfSpace)
        .ignoresSafeArea()
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

// MARK: - Pill de biblioteca

private struct NotchShelfLibraryPill: View {
    let name: String
    let count: Int
    let isActive: Bool
    let pointer: NotchShelfPointer
    let onTap: () -> Void

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
    }
}

// MARK: - Tile de slot (misma lógica visual que `SlotCardView`)

private struct NotchShelfTile: View {
    let slot: Slot
    let pointer: NotchShelfPointer
    let onActivate: () -> Void
    let onDropFile: (URL) -> Void

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
                        Text(SlotCardCopy.metaPrimary(for: slot))
                            .font(SlotsFont.etiqueta)
                            .foregroundStyle(prefersLight ? Color.white.opacity(0.85) : SlotsColor.textoSecundario)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        // Solo lectura: enseña el atajo. Se edita desde el panel.
                        SlotHandoffShortcutChip(
                            name: hasContent
                                ? KeyboardShortcuts.Name.pasteSlotNames[slot.index - 1]
                                : KeyboardShortcuts.Name.copyToSlotNames[slot.index - 1],
                            ink: SlotsColor.textoSecundario,
                            plate: prefersLight ? Color.white.opacity(0.9) : SlotsColor.teclaFondo
                        )
                        .layoutPriority(1)
                    }

                    if case .file = slot.content, let content = slot.content {
                        FileClipIconView(content: content, side: 40)
                        Text(content.fileName)
                            .font(SlotsFont.etiqueta)
                            .foregroundStyle(SlotsColor.tinta)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else if let preview = SlotCardCopy.contentBodyPreview(for: slot), !isImage {
                        Text(preview)
                            .font(SlotsFont.etiqueta)
                            .foregroundStyle(prefersLight ? Color.white : SlotsColor.tinta)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    } else if !hasContent {
                        // Sin botón de guardar: el clic en un slot vacío guarda el portapapeles.
                        Text("Clic para guardar el portapapeles")
                            .font(SlotsFont.etiqueta)
                            .foregroundStyle(SlotsColor.textoSecundario)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)

                    Text(SlotCardCopy.visibleCardTitle(for: slot))
                        .font(.custom("InterTight-Medium", size: 16))
                        .foregroundStyle(titleColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .shadow(color: Color.black.opacity(prefersLight ? 0.55 : 0), radius: 5, y: 1)
                .padding(SlotsSpace.s + 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background { scrims }
            }
            .frame(width: NotchShelfMetrics.tile, height: NotchShelfMetrics.tile)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .buttonStyle(.plain)
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

    // MARK: Acción

    private func press() {
        withAnimation(.easeOut(duration: 0.07)) { pressScale = 0.92 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pressScale = 1 }
            onActivate()
        }
    }

    // MARK: Propiedades del slot

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
        return SlotsColor.papel
    }

    private var chrome: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(chromeFill)

            if hasContent, SlotsPalette.isBrandGradient(backgroundHex) {
                Image("DegradeNaranja")
                    .resizable()
                    .scaledToFill()
                    .frame(width: NotchShelfMetrics.tile, height: NotchShelfMetrics.tile)
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
        .frame(width: NotchShelfMetrics.tile, height: NotchShelfMetrics.tile)
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
                .frame(height: 40)
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 70)
            }
            .allowsHitTesting(false)
        }
    }
}
