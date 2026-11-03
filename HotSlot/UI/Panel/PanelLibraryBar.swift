import SwiftUI
import UniformTypeIdentifiers

/// Pills de bibliotecas + «Guardar portapapeles» (handoff `Main.html`).
struct PanelLibraryBar: View {
    @Bindable var appState: AppState
    @State private var libraryDropTargetId: UUID?
    @State private var libraryBeingDragged: UUID?

    private var libraries: [Library] {
        appState.libraryWorkspace.workspace.libraries.sorted { $0.order < $1.order }
    }

    private var activeId: UUID {
        appState.libraryWorkspace.workspace.activeLibraryId
    }

    var body: some View {
        HStack(spacing: SlotsSpace.m) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SlotsSpace.s) {
                    ForEach(libraries) { library in
                        libraryPill(library)
                    }
                    addLibraryButton

                    if libraryBeingDragged != nil, libraries.count > 1 {
                        libraryTrashDropTarget
                    }
                }
            }

            saveClipboardButton
        }
        .padding(.horizontal, HotSlotDesign.horizontalPadding)
    }

    private func libraryPill(_ library: Library) -> some View {
        let isActive = library.id == activeId
        let count = appState.libraryWorkspace.filledSlotCount(in: library.id)
        let isDropTarget = libraryDropTargetId == library.id
        let shiftForReorder = isDropTarget && libraryBeingDragged != nil && libraryBeingDragged != library.id

        return Button {
            guard library.id != activeId else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                appState.switchLibrary(to: library.id)
            }
        } label: {
            HStack(spacing: SlotsSpace.s) {
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
            .overlay(alignment: .leading) {
                if isDropTarget {
                    Capsule(style: .continuous)
                        .strokeBorder(SlotsColor.naranja, lineWidth: 2)
                        .padding(-2)
                }
            }
            .foregroundStyle(isActive ? Color.white : SlotsColor.tinta)
        }
        .buttonStyle(.plain)
        .offset(x: shiftForReorder ? 10 : 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: shiftForReorder)
        .draggable(PanelDragPayload.library(id: library.id)) {
            Text(library.name)
                .font(SlotsFont.textoUI)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .onAppear { libraryBeingDragged = library.id }
        }
        .onDrop(of: [UTType.hotslotPanelDrag], isTargeted: Binding(
            get: { libraryDropTargetId == library.id },
            set: { libraryDropTargetId = $0 ? library.id : nil }
        )) { providers in
            libraryBeingDragged = nil
            return acceptLibraryDrop(providers, targetId: library.id)
        }
        .contextMenu {
            if libraries.count > 1 {
                Button("Eliminar «\(library.name)»…", role: .destructive) {
                    appState.deleteLibraryConfirmation = library
                }
            }
        }
    }

    private var libraryTrashDropTarget: some View {
        Image(systemName: "trash")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(SlotsColor.naranja)
            .frame(width: SlotsRadius.controlAlto, height: SlotsRadius.controlAlto)
            .background {
                Circle()
                    .strokeBorder(SlotsColor.naranja.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            .help("Soltá acá para eliminar la biblioteca")
            .onDrop(of: [UTType.hotslotPanelDrag], isTargeted: nil) { providers in
                acceptLibraryTrashDrop(providers)
            }
    }

    private func acceptLibraryTrashDrop(_ providers: [NSItemProvider]) -> Bool {
        let type = UTType.hotslotPanelDrag.identifier
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(type) }) else {
            return false
        }
        provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
            guard let data,
                  let payload = try? JSONDecoder().decode(PanelDragPayload.self, from: data),
                  case .library(let draggedId) = payload else { return }
            DispatchQueue.main.async {
                libraryBeingDragged = nil
                if let library = libraries.first(where: { $0.id == draggedId }) {
                    appState.deleteLibraryConfirmation = library
                }
            }
        }
        return true
    }

    private func acceptLibraryDrop(_ providers: [NSItemProvider], targetId: UUID) -> Bool {
        let type = UTType.hotslotPanelDrag.identifier
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(type) }) else {
            return false
        }
        provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
            guard let data,
                  let payload = try? JSONDecoder().decode(PanelDragPayload.self, from: data),
                  case .library(let draggedId) = payload,
                  draggedId != targetId else { return }
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    appState.reorderLibrary(draggedId: draggedId, before: targetId)
                }
                libraryBeingDragged = nil
                libraryDropTargetId = nil
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
