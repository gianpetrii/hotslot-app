import SwiftUI

struct HistoryListView: View {
    @Bindable var historyStore: HistoryStore
    let panelController: PanelController
    let onPaste: (ClipItem) -> Void
    @Binding var selectedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: HotSlotDesign.sectionSpacing) {
            SectionHeader(title: "Historial")

            if historyStore.items.isEmpty {
                EmptyStateView(
                    title: "Sin historial",
                    systemImage: "clock",
                    subtitle: "Copia algo en cualquier app y aparecerá aquí"
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(historyStore.items.enumerated()), id: \.element.id) { offset, item in
                                ClipRowView(item: item, isSelected: selectedIndex == offset)
                                    .id(item.id)
                                    .onTapGesture {
                                        selectedIndex = offset
                                        onPaste(item)
                                    }
                                    .contextMenu {
                                        Button("Pegar") { onPaste(item) }
                                        Button("Eliminar", role: .destructive) {
                                            historyStore.remove(id: item.id)
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, HotSlotDesign.horizontalPadding - 4)
                        .padding(.bottom, 8)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: selectedIndex) { _, newValue in
                        if let idx = newValue, let id = historyStore.items[safe: idx]?.id {
                            withAnimation { proxy.scrollTo(id, anchor: .center) }
                        }
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
