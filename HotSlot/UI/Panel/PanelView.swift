import SwiftUI

struct PanelView: View {
    @Bindable var appState: AppState
    let panelController: PanelController
    @State private var selectedHistoryIndex: Int?

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                header
                Divider()
                SlotGridView(appState: appState, panelController: panelController)
                    .padding(.vertical, 8)
                Divider()
                HistoryListView(
                    appState: appState,
                    panelController: panelController,
                    selectedIndex: $selectedHistoryIndex
                )
            }
            .frame(width: 420, height: 480)
            .background(.ultraThinMaterial)

            if let toast = appState.toastMessage {
                ToastView(message: toast)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.toastMessage)
        .onKeyPress(.upArrow) {
            moveSelection(delta: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(delta: 1)
            return .handled
        }
        .onKeyPress(.return) {
            pasteSelectedItem()
            return .handled
        }
        .onAppear {
            if selectedHistoryIndex == nil, !appState.historyStore.items.isEmpty {
                selectedHistoryIndex = 0
            }
        }
    }

    private func moveSelection(delta: Int) {
        let count = appState.historyStore.items.count
        guard count > 0 else { return }
        let current = selectedHistoryIndex ?? 0
        let next = max(0, min(count - 1, current + delta))
        selectedHistoryIndex = next
    }

    private func pasteSelectedItem() {
        guard let index = selectedHistoryIndex,
              index < appState.historyStore.items.count else { return }
        appState.pasteItem(appState.historyStore.items[index], panelController: panelController)
    }

    private var header: some View {
        HStack {
            Image(systemName: "doc.on.clipboard.fill")
                .foregroundStyle(Color.accentColor)
            Text("HotSlot")
                .font(.headline)
            Spacer()
            Text("⌘⇧V")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button {
                panelController.hide()
                appState.isPanelVisible = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Cerrar (Esc)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
