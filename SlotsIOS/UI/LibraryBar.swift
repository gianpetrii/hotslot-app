import SwiftUI
import UniformTypeIdentifiers

/// Barra inferior de bibliotecas: pills con scroll horizontal y «+» para crear una.
struct LibraryBar: View {
    let libraries: [Library]
    let activeId: UUID
    let count: (UUID) -> Int
    let onSelect: (UUID) -> Void
    let onAdd: () -> Void
    var onRename: (Library) -> Void = { _ in }
    var onDelete: (Library) -> Void = { _ in }
    /// Pill resaltada porque un slot arrastrado está encima.
    var highlightedId: UUID?
    /// Hay un slot arrastrándose: las pills lo reciben en vez de reordenarse.
    var onSlotHover: (UUID?) -> Void = { _ in }
    var onSlotDrop: (UUID) -> Void = { _ in }
    /// Mantener y arrastrar una pill la reordena. `index` cuenta sin la biblioteca movida.
    var onMove: (UUID, Int) -> Void = { _, _ in }

    @State private var draggingId: UUID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SlotsSpace.s) {
                    ForEach(libraries) { library in
                        pill(library).id(library.id)
                    }
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(SlotsColor.tinta)
                            .frame(width: 48, height: 48)
                            .overlay {
                                Circle().strokeBorder(SlotsColor.bordePunteado, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            }
                    }
                    .accessibilityLabel("Nueva biblioteca")
                }
                .padding(.horizontal, SlotsSpace.m)
            }
            .onChange(of: activeId) { _, id in
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .scrollClipDisabled()
        .padding(.top, 20)
        .padding(.bottom, 6)
        .background {
            // Fondo papel sólido con un fundido corto de 10 pt arriba.
            VStack(spacing: 0) {
                LinearGradient(colors: [SlotsColor.papel.opacity(0), SlotsColor.papel], startPoint: .top, endPoint: .bottom)
                    .frame(height: 10)
                SlotsColor.papel
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func pill(_ library: Library) -> some View {
        let isActive = library.id == activeId
        return Button { onSelect(library.id) } label: {
            HStack(spacing: SlotsSpace.s) {
                Text(library.name)
                    .slotsText(15)
                    .lineLimit(1)
                if isActive {
                    Text("\(count(library.id))")
                        .slotsText(12)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(SlotsColor.naranja, in: Circle())
                }
            }
            .foregroundStyle(isActive ? .white : SlotsColor.tinta)
            .padding(.leading, 20)
            .padding(.trailing, isActive ? 8 : 20)
            .frame(height: SlotsRadius.controlAlto)
            .background(isActive ? SlotsColor.tinta : .white, in: Capsule())
        }
        .buttonStyle(.plain)
        .contentShape(.dragPreview, Capsule())
        .contentShape(.contextMenuPreview, Capsule())
        .onDrag {
            draggingId = library.id
            let provider = NSItemProvider()
            provider.registerDataRepresentation(forTypeIdentifier: UTType.slotsLibraryDrag.identifier, visibility: .ownProcess) { done in
                done(Data(library.id.uuidString.utf8), nil)
                return nil
            }
            return provider
        }
        .onDrop(of: [.slotsSlotDrag, .slotsLibraryDrag], delegate: LibraryDropDelegate(
            target: library,
            libraries: libraries,
            draggingId: $draggingId,
            onMove: onMove,
            onSlotHover: onSlotHover,
            onSlotDrop: onSlotDrop
        ))
        .overlay {
            if highlightedId == library.id {
                Capsule().strokeBorder(SlotsColor.naranja, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
        }
        .contextMenu {
            Button("Renombrar", systemImage: "pencil") { onRename(library) }
            if libraries.count > 1 {
                Button("Eliminar biblioteca", systemImage: "trash", role: .destructive) { onDelete(library) }
            }
        }
        .accessibilityLabel(isActive ? "\(library.name), \(count(library.id)) slots, seleccionada" : library.name)
    }
}

private struct LibraryDropDelegate: DropDelegate {
    let target: Library
    let libraries: [Library]
    @Binding var draggingId: UUID?
    let onMove: (UUID, Int) -> Void
    let onSlotHover: (UUID?) -> Void
    let onSlotDrop: (UUID) -> Void

    /// Una pill arrastrándose manda sobre un slot: solo se reordena entre pills.
    private func isSlotDrag(_ info: DropInfo) -> Bool { !info.hasItemsConforming(to: [.slotsLibraryDrag]) }

    func dropEntered(info: DropInfo) {
        if isSlotDrag(info) {
            onSlotHover(target.id)
            return
        }
        guard let from = draggingId, from != target.id,
              let targetIndex = libraries.firstIndex(where: { $0.id == target.id }) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onMove(from, targetIndex)
    }

    func dropExited(info: DropInfo) {
        if isSlotDrag(info) { onSlotHover(nil) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        if isSlotDrag(info) {
            onSlotDrop(target.id)
            return true
        }
        draggingId = nil
        return true
    }
}
