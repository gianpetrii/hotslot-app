import SwiftUI

struct HistoryListView: View {
    @Bindable var appState: AppState
    let panelController: PanelController
    @Binding var selectedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Historial")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            if appState.historyStore.items.isEmpty {
                EmptyStateView(
                    title: "Sin historial",
                    systemImage: "clock",
                    subtitle: "Copia algo y aparecerá aquí"
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(appState.historyStore.items.enumerated()), id: \.element.id) { offset, item in
                                ClipRowView(item: item, isSelected: selectedIndex == offset)
                                    .id(offset)
                                    .onTapGesture {
                                        selectedIndex = offset
                                        appState.pasteItem(item, panelController: panelController)
                                    }
                                    .contextMenu {
                                        Button("Pegar") {
                                            appState.pasteItem(item, panelController: panelController)
                                        }
                                        Button("Eliminar", role: .destructive) {
                                            appState.historyStore.remove(id: item.id)
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .onChange(of: selectedIndex) { _, newValue in
                        if let idx = newValue {
                            withAnimation { proxy.scrollTo(idx, anchor: .center) }
                        }
                    }
                }
            }
        }
    }
}
