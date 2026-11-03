import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Pills de bibliotecas + «Guardar portapapeles» (handoff `Main.html`).
struct PanelLibraryBar: View {
    @Bindable var appState: AppState
    @State private var libraryDropTargetId: UUID?
    @State private var libraryBeingDragged: UUID?
    @State private var isTrashDropTarget = false

    private var libraries: [Library] {
        appState.libraryWorkspace.workspace.libraries.sorted { $0.order < $1.order }
    }

    private var activeId: UUID {
        appState.libraryWorkspace.workspace.activeLibraryId
    }

    private var isLibraryDragActive: Bool {
        libraryBeingDragged != nil
    }

    var body: some View {
        HStack(spacing: SlotsSpace.m) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SlotsSpace.s) {
                    ForEach(libraries) { library in
                        libraryPillRow(library)
                    }
                    addLibraryButton
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }

            if libraries.count > 1 {
                libraryTrashDropTarget
            }

            saveClipboardButton
        }
        .padding(.horizontal, HotSlotDesign.horizontalPadding)
        .onChange(of: libraryDropTargetId) { _, _ in
            clearLibraryDragIfIdle()
        }
        .onChange(of: isTrashDropTarget) { _, _ in
            clearLibraryDragIfIdle()
        }
    }

    private func clearLibraryDragIfIdle() {
        guard libraryBeingDragged != nil else { return }
        guard libraryDropTargetId == nil, !isTrashDropTarget else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if libraryDropTargetId == nil, !isTrashDropTarget {
                libraryBeingDragged = nil
            }
        }
    }

    @ViewBuilder
    private func libraryPillRow(_ library: Library) -> some View {
        let showInsertMark = libraryDropTargetId == library.id
            && libraryBeingDragged != nil
            && libraryBeingDragged != library.id

        HStack(spacing: 6) {
            if showInsertMark {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(SlotsColor.naranja)
                    .frame(width: 3, height: SlotsRadius.controlAlto - 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.6, anchor: .leading)))
            }
            libraryPill(library)
        }
        .animation(.easeOut(duration: 0.16), value: showInsertMark)
    }

    private func libraryPill(_ library: Library) -> some View {
        let isActive = library.id == activeId
        let count = appState.libraryWorkspace.filledSlotCount(in: library.id)
        let isDropTarget = libraryDropTargetId == library.id
        let isDragSource = library.id == libraryBeingDragged

        return HStack(spacing: SlotsSpace.s) {
            Text(library.name)
                .font(SlotsFont.textoUI)
            countBadge(count: count, isActive: isActive)
        }
        .padding(.leading, 20)
        .padding(.trailing, SlotsSpace.s)
        .frame(height: SlotsRadius.controlAlto)
        .background {
            Capsule(style: .continuous)
                .fill(isActive ? SlotsColor.tinta : Color.white.opacity(0.85))
        }
        .overlay {
            if isDropTarget, isLibraryDragActive {
                Capsule(style: .continuous)
                    .strokeBorder(SlotsColor.naranja, lineWidth: 2)
            } else if isDropTarget {
                Capsule(style: .continuous)
                    .strokeBorder(SlotsColor.naranja.opacity(0.45), lineWidth: 1.5)
            }
        }
        .foregroundStyle(isActive ? Color.white : SlotsColor.tinta)
        .scaleEffect(isDropTarget && isLibraryDragActive ? 1.03 : 1)
        .opacity(isDragSource ? 0.38 : 1)
        .animation(.easeOut(duration: 0.14), value: isDropTarget)
        .animation(.easeOut(duration: 0.12), value: isDragSource)
        .contentShape(Capsule(style: .continuous))
        .onTapGesture {
            guard library.id != activeId else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                appState.switchLibrary(to: library.id)
            }
        }
        .contextMenu {
            Button("Renombrar…") {
                appState.renameLibraryTarget = library
            }
            Divider()
            if libraries.count > 1 {
                Button("Eliminar «\(library.name)»…", role: .destructive) {
                    appState.deleteLibraryConfirmation = library
                }
            }
        }
        .help("Clic para cambiar · Arrastrá para reordenar · Clic derecho para renombrar")
        .onDrag {
            libraryBeingDragged = library.id
            let data = (try? JSONEncoder().encode(LibraryDragPayload(id: library.id))) ?? Data()
            return NSItemProvider(item: data as NSData, typeIdentifier: UTType.hotslotLibraryDrag.identifier)
        }
        .onDrop(of: [UTType.hotslotLibraryDrag], isTargeted: Binding(
            get: { libraryDropTargetId == library.id },
            set: { targeted in
                libraryDropTargetId = targeted ? library.id : nil
                if !targeted, libraryBeingDragged == library.id {
                    libraryBeingDragged = nil
                }
            }
        )) { providers in
            defer {
                libraryBeingDragged = nil
                libraryDropTargetId = nil
            }
            return acceptLibraryReorder(providers, before: library.id)
        }
    }

    private var libraryTrashDropTarget: some View {
        let active = isTrashDropTarget && isLibraryDragActive

        return Image(systemName: "trash")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(active ? Color.white : SlotsColor.naranja)
            .frame(width: SlotsRadius.controlAlto, height: SlotsRadius.controlAlto)
            .background {
                Circle()
                    .fill(active ? SlotsColor.naranja : Color.white.opacity(0.85))
                    .overlay {
                        Circle()
                            .strokeBorder(
                                SlotsColor.naranja.opacity(active ? 1 : 0.45),
                                lineWidth: active ? 0 : 1.5
                            )
                    }
            }
            .scaleEffect(active ? 1.06 : 1)
            .animation(.easeOut(duration: 0.12), value: active)
            .help("Arrastrá una biblioteca acá para eliminarla")
            .onDrop(of: [UTType.hotslotLibraryDrag], isTargeted: $isTrashDropTarget) { providers in
                defer {
                    libraryBeingDragged = nil
                    isTrashDropTarget = false
                }
                return acceptLibraryTrashDrop(providers)
            }
    }

    private func acceptLibraryReorder(_ providers: [NSItemProvider], before targetId: UUID) -> Bool {
        let type = UTType.hotslotLibraryDrag.identifier
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(type) }) else {
            return false
        }
        provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
            guard let data,
                  let payload = try? JSONDecoder().decode(LibraryDragPayload.self, from: data),
                  payload.id != targetId else { return }
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    appState.reorderLibrary(draggedId: payload.id, before: targetId)
                }
            }
        }
        return true
    }

    private func acceptLibraryTrashDrop(_ providers: [NSItemProvider]) -> Bool {
        let type = UTType.hotslotLibraryDrag.identifier
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(type) }) else {
            return false
        }
        provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
            guard let data,
                  let payload = try? JSONDecoder().decode(LibraryDragPayload.self, from: data),
                  let library = libraries.first(where: { $0.id == payload.id }) else { return }
            DispatchQueue.main.async {
                appState.deleteLibraryConfirmation = library
            }
        }
        return true
    }

    private func countBadge(count: Int, isActive: Bool) -> some View {
        Text("\(count)")
            .font(SlotsFont.etiqueta)
            .foregroundStyle(isActive ? Color.white : SlotsColor.tinta)
            .frame(minWidth: 26, minHeight: 26)
            .background {
                Circle()
                    .fill(isActive ? SlotsColor.naranja : Color.black.opacity(0.07))
            }
    }

    private var addLibraryButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                appState.isNewLibraryFormPresented = true
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SlotsColor.tinta)
                .frame(width: SlotsRadius.controlAlto, height: SlotsRadius.controlAlto)
                .contentShape(Circle())
                .background {
                    Circle()
                        .strokeBorder(Color.black.opacity(0.28), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
        }
        .buttonStyle(.plain)
        .help("Nueva biblioteca")
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
