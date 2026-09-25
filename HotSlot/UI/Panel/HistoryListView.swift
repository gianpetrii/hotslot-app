import SwiftUI

struct HistoryListView: View {
    @Bindable var historyStore: HistoryStore
    let items: [ClipItem]
    let isSearching: Bool
    let onPaste: (ClipItem) -> Void
    @Binding var keyboardHighlightIndex: Int?

    private let listAnimation = Animation.spring(response: 0.34, dampingFraction: 0.82)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Historial")

            if items.isEmpty {
                EmptyStateView(
                    title: isSearching ? "Sin resultados" : "Sin historial",
                    systemImage: isSearching ? "magnifyingglass" : "clock",
                    subtitle: isSearching
                        ? "Probá con otro término de búsqueda"
                        : "Copiá algo en cualquier app y aparecerá aquí"
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(items) { item in
                            let offset = items.firstIndex(where: { $0.id == item.id }) ?? 0
                            ClipRowView(
                                item: item,
                                isKeyboardHighlighted: keyboardHighlightIndex == offset,
                                onPaste: { onPaste(item) },
                                onTogglePin: {
                                    withAnimation(listAnimation) {
                                        historyStore.togglePin(id: item.id)
                                    }
                                }
                            )
                            .id(item.id)
                            .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .contextMenu {
                                Button(item.isPinned ? "Desfijar" : "Fijar arriba") {
                                    withAnimation(listAnimation) {
                                        historyStore.togglePin(id: item.id)
                                    }
                                }
                                Button("Pegar") { onPaste(item) }
                                Button("Eliminar", role: .destructive) {
                                    withAnimation(listAnimation) {
                                        historyStore.remove(id: item.id)
                                    }
                                }
                            }
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .scale(scale: 0.94, anchor: .top).combined(with: .opacity)
                                )
                            )
                        }
                        .onMove { source, destination in
                            guard !isSearching else { return }
                            withAnimation(listAnimation) {
                                historyStore.move(from: source, to: destination)
                            }
                        }
                        .moveDisabled(isSearching)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .environment(\.defaultMinListRowHeight, HotSlotDesign.rowHeight)
                    .animation(listAnimation, value: items.map(\.id))
                    .onChange(of: keyboardHighlightIndex) { _, newValue in
                        if let idx = newValue, let id = items[safe: idx]?.id {
                            withAnimation(listAnimation) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(listAnimation, value: items.map(\.id))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
