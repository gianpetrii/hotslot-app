import SwiftUI
import UniformTypeIdentifiers

struct HistoryListView: View {
    @Bindable var historyStore: HistoryStore
    let items: [ClipItem]
    let isSearching: Bool
    let onPaste: (ClipItem) -> Void
    @Binding var keyboardHighlightIndex: Int?
    var isDemo: Bool = false

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
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(items) { item in
                                let offset = items.firstIndex(where: { $0.id == item.id }) ?? 0
                                ClipRowView(
                                    item: item,
                                    isKeyboardHighlighted: keyboardHighlightIndex == offset,
                                    isDemo: isDemo,
                                    onPaste: { onPaste(item) },
                                    onTogglePin: {
                                        withAnimation(listAnimation) {
                                            historyStore.togglePin(id: item.id)
                                        }
                                    }
                                )
                                .id(item.id)
                                .padding(.horizontal, 8)
                                .modifier(HistoryRowChromeModifier(
                                    isDemo: isDemo,
                                    item: item,
                                    isSearching: isSearching,
                                    historyStore: historyStore,
                                    onPaste: { onPaste(item) }
                                ))
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .scale(scale: 0.94, anchor: .top).combined(with: .opacity)
                                    )
                                )
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .scrollIndicators(.hidden)
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

    fileprivate static func acceptHistoryDrop(
        _ providers: [NSItemProvider],
        handle: @escaping (UUID) -> Void
    ) -> Bool {
        let type = UTType.hotslotPanelDrag.identifier
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(type) }) else {
            return false
        }
        provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
            guard let data,
                  let payload = try? JSONDecoder().decode(PanelDragPayload.self, from: data),
                  case .historyItem(let id) = payload else { return }
            DispatchQueue.main.async {
                handle(id)
            }
        }
        return true
    }
}

private struct HistoryRowChromeModifier: ViewModifier {
    let isDemo: Bool
    let item: ClipItem
    let isSearching: Bool
    @Bindable var historyStore: HistoryStore
    let onPaste: () -> Void

    private let listAnimation = Animation.spring(response: 0.34, dampingFraction: 0.82)

    func body(content: Content) -> some View {
        if isDemo {
            content
        } else {
            content
                .contextMenu {
                    Button(item.isPinned ? "Desfijar" : "Fijar arriba") {
                        withAnimation(listAnimation) {
                            historyStore.togglePin(id: item.id)
                        }
                    }
                    Button("Pegar", action: onPaste)
                    Button("Eliminar", role: .destructive) {
                        withAnimation(listAnimation) {
                            historyStore.remove(id: item.id)
                        }
                    }
                }
                .onDrop(of: [UTType.hotslotPanelDrag], isTargeted: nil) { providers in
                    guard !isSearching else { return false }
                    return HistoryListView.acceptHistoryDrop(providers) { sourceID in
                        withAnimation(listAnimation) {
                            historyStore.moveItem(id: sourceID, before: item.id)
                        }
                    }
                }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
