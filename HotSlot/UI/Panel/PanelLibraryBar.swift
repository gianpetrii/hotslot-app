import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Pills de bibliotecas + «Guardar portapapeles» (handoff `Main.html`).
struct PanelLibraryBar: View {
    @Bindable var appState: AppState
    @State private var pillHoverTargetId: UUID?
    @State private var contentSwitchTask: Task<Void, Never>?
    @State private var pillFrames: [UUID: CGRect] = [:]
    @State private var barFrame: CGRect = .zero
    @State private var hoveredLibraryId: UUID?
    @State private var addClickScale: CGFloat = 1

    private let contentSwitchDwell: TimeInterval = 0.55
    private let reorderAnimation = Animation.spring(response: 0.28, dampingFraction: 0.82)
    private let settleDuration: TimeInterval = 0.3

    private var libraries: [Library] {
        appState.libraryWorkspace.workspace.libraries.sorted { $0.order < $1.order }
    }

    /// Durante el arrastre, la pill arrastrada (como fantasma) se ubica en el punto de inserción.
    private var displayedLibraries: [Library] {
        let visible = libraries.filter { appState.deleteLibraryConfirmation?.id != $0.id }
        guard let drag = appState.libraryDrag,
              let dragged = visible.first(where: { $0.id == drag.libraryId }) else { return visible }
        var others = visible.filter { $0.id != drag.libraryId }
        others.insert(dragged, at: min(drag.insertIndex, others.count))
        return others
    }

    private var activeId: UUID {
        appState.libraryWorkspace.workspace.activeLibraryId
    }

    var body: some View {
        HStack(spacing: SlotsSpace.m) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SlotsSpace.s) {
                    ForEach(displayedLibraries) { library in
                        libraryPill(library)
                    }
                    addLibraryButton
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 8)
            }
            .scrollClipDisabled()
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { barFrame = geo.frame(in: .named(PanelView.coordinateSpaceName)) }
                        .onChange(of: geo.frame(in: .named(PanelView.coordinateSpaceName))) { _, frame in
                            barFrame = frame
                        }
                }
            }

            saveClipboardButton
        }
        .padding(.horizontal, HotSlotDesign.horizontalPadding)
        .onPreferenceChange(LibraryPillFramesKey.self) { pillFrames = $0 }
        .onChange(of: pillHoverTargetId) { _, targetId in
            scheduleContentLibrarySwitch(to: targetId)
        }
        .onDisappear {
            contentSwitchTask?.cancel()
        }
    }

    private func libraryPill(_ library: Library) -> some View {
        let isActive = library.id == activeId
        let isGhost = appState.libraryDragActiveId == library.id
        let isSlotDropHover = pillHoverTargetId == library.id && library.id != activeId

        return LibraryPillLabel(
            name: library.name,
            count: appState.libraryWorkspace.filledSlotCount(in: library.id),
            isActive: isActive
        )
        .overlay {
            if isGhost {
                Capsule(style: .continuous)
                    .strokeBorder(SlotsColor.tinta.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            } else if isSlotDropHover {
                Capsule(style: .continuous)
                    .strokeBorder(SlotsColor.naranja.opacity(0.4), lineWidth: 1.5)
            }
        }
        .opacity(isGhost ? 0.3 : 1)
        .slotsHoverLift(hoveredLibraryId == library.id && !isActive && !isGhost, scales: true)
        .onHover { hovering in
            hoveredLibraryId = hovering ? library.id : (hoveredLibraryId == library.id ? nil : hoveredLibraryId)
        }
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: LibraryPillFramesKey.self,
                    value: [library.id: geo.frame(in: .named(PanelView.coordinateSpaceName))]
                )
            }
        }
        .contentShape(Capsule(style: .continuous))
        .onTapGesture {
            guard library.id != activeId else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                appState.switchLibrary(to: library.id)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named(PanelView.coordinateSpaceName))
                .onChanged { value in updateLibraryDrag(library, value: value) }
                .onEnded { _ in finishLibraryDrag() }
        )
        .contextMenu {
            Button("Renombrar…") {
                appState.renameLibraryTarget = library
            }
            Divider()
            if libraries.count > 1 {
                Button("Eliminar «\(library.name)»…", role: .destructive) {
                    withAnimation(reorderAnimation) {
                        appState.requestDeleteLibrary(library)
                    }
                }
            }
        }
        .help("Clic cambiar · Arrastrá para reordenar o soltá en el tacho para eliminar")
        .onDrop(of: [UTType.hotslotPanelDrag], isTargeted: Binding(
            get: { pillHoverTargetId == library.id },
            set: { pillHoverTargetId = $0 ? library.id : nil }
        )) { _ in
            false
        }
    }

    // MARK: - Arrastre de bibliotecas

    private func updateLibraryDrag(_ library: Library, value: DragGesture.Value) {
        if appState.libraryDrag == nil {
            guard let originIndex = libraries.firstIndex(where: { $0.id == library.id }),
                  let frame = pillFrames[library.id] else { return }
            contentSwitchTask?.cancel()
            appState.libraryDrag = LibraryDragSession(
                libraryId: library.id,
                originIndex: originIndex,
                startFrame: frame,
                translation: value.translation,
                location: value.location,
                insertIndex: originIndex
            )
        }
        guard var drag = appState.libraryDrag, drag.libraryId == library.id, !drag.isSettling else { return }
        drag.translation = value.translation
        drag.location = value.location

        let newIndex = insertionIndex(for: drag)
        if newIndex != drag.insertIndex {
            drag.insertIndex = newIndex
            withAnimation(reorderAnimation) {
                appState.libraryDrag = drag
            }
        } else {
            appState.libraryDrag = drag
        }
    }

    /// Lejos de la barra (p. ej. yendo al tacho) la pill vuelve a su lugar original.
    private func insertionIndex(for drag: LibraryDragSession) -> Int {
        guard barFrame.insetBy(dx: -24, dy: -32).contains(drag.location) else {
            return drag.originIndex
        }
        let others = libraries.filter { $0.id != drag.libraryId }
        return others.filter { (pillFrames[$0.id]?.midX ?? .infinity) < drag.location.x }.count
    }

    private func finishLibraryDrag() {
        guard let drag = appState.libraryDrag, !drag.isSettling,
              let library = libraries.first(where: { $0.id == drag.libraryId }) else {
            return
        }

        if appState.floatingLibraryTrashTargeted {
            withAnimation(reorderAnimation) {
                appState.libraryDrag = nil
                appState.requestDeleteLibrary(library)
            }
            return
        }

        if drag.insertIndex != drag.originIndex {
            appState.moveLibrary(id: library.id, toIndex: drag.insertIndex)
        }

        guard let landing = pillFrames[library.id] else {
            appState.libraryDrag = nil
            return
        }

        var settling = drag
        settling.isSettling = true
        settling.translation = CGSize(
            width: landing.midX - drag.startFrame.midX,
            height: landing.midY - drag.startFrame.midY
        )
        withAnimation(.spring(response: settleDuration, dampingFraction: 0.82)) {
            appState.libraryDrag = settling
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDuration) {
            guard appState.libraryDrag?.isSettling == true,
                  appState.libraryDrag?.libraryId == library.id else { return }
            withAnimation(.easeOut(duration: 0.12)) {
                appState.libraryDrag = nil
            }
        }
    }

    private func scheduleContentLibrarySwitch(to targetId: UUID?) {
        contentSwitchTask?.cancel()
        guard let targetId,
              appState.libraryDrag == nil,
              targetId != activeId else { return }

        contentSwitchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(contentSwitchDwell * 1_000_000_000))
            guard !Task.isCancelled, pillHoverTargetId == targetId else { return }
            guard appState.libraryDrag == nil else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                appState.switchLibrary(to: targetId)
            }
        }
    }

    private var addLibraryButton: some View {
        Button(action: playAddClick) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
        }
        .buttonStyle(AddLibraryButtonStyle())
        .scaleEffect(addClickScale)
        .animation(.spring(response: 0.34, dampingFraction: 0.55), value: addClickScale)
        .help("Nueva biblioteca")
    }

    /// El pulso corre entero aunque el clic dure un instante. El formulario entra cuando el botón ya se achicó.
    private func playAddClick() {
        withAnimation(.easeOut(duration: 0.07)) { addClickScale = 0.84 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.55)) { addClickScale = 1 }
            withAnimation(.easeOut(duration: 0.18)) {
                appState.isNewLibraryFormPresented = true
            }
        }
    }

    private var saveClipboardButton: some View {
        Button {
            appState.saveClipboardFromPanel()
        } label: {
            HStack(spacing: 0) {
                Text("Guardar portapapeles")
                    .font(SlotsFont.textoUI)
                    .foregroundStyle(.white)
                    .padding(.leading, 20)
                    .padding(.trailing, 14)

                Text("›")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                    }
                    .padding(.trailing, 6)
            }
            .frame(height: SlotsRadius.controlAlto)
            .background {
                Capsule(style: .continuous)
                    .fill(SlotsColor.cardOscura)
            }
        }
        .buttonStyle(.plain)
        .help("Guarda el portapapeles en el primer slot vacío")
    }
}

private struct AddLibraryButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(SlotsColor.textoSecundario)
            .frame(width: SlotsRadius.controlAlto, height: SlotsRadius.controlAlto)
            .background {
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .overlay {
                        Circle()
                            .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                    }
            }
            .slotsHoverLift(isHovering, scales: true)
            .animation(.easeOut(duration: 0.16), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

/// Pill de biblioteca (barra y copia flotante durante el arrastre).
struct LibraryPillLabel: View {
    let name: String
    let count: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: SlotsSpace.s) {
            Text(name)
                .font(SlotsFont.textoUI)
            Text("\(count)")
                .font(SlotsFont.etiqueta)
                .foregroundStyle(isActive ? Color.white : SlotsColor.tinta)
                .frame(minWidth: 26, minHeight: 26)
                .background {
                    Circle()
                        .fill(isActive ? SlotsColor.naranja : Color.black.opacity(0.07))
                }
        }
        .padding(.leading, 20)
        .padding(.trailing, SlotsSpace.s)
        .frame(height: SlotsRadius.controlAlto)
        .background {
            Capsule(style: .continuous)
                .fill(isActive ? SlotsColor.tinta : Color.white.opacity(0.85))
        }
        .foregroundStyle(isActive ? Color.white : SlotsColor.tinta)
    }
}

private struct LibraryPillFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}
