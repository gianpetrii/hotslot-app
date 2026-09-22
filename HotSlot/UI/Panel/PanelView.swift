import SwiftUI

struct PanelView: View {
    @Bindable var appState: AppState
    let panelController: PanelController
    @State private var selectedHistoryIndex: Int?

    var body: some View {
        ZStack(alignment: .bottom) {
            PanelChrome {
                VStack(spacing: 0) {
                    header
                    Divider().opacity(0.35)
                    SlotGridView(appState: appState, panelController: panelController)
                        .padding(.vertical, HotSlotDesign.sectionSpacing)
                    Divider().opacity(0.35)
                    HistoryListView(
                        historyStore: appState.historyStore,
                        panelController: panelController,
                        onPaste: { item in
                            appState.pasteItem(item, panelController: panelController)
                        },
                        selectedIndex: $selectedHistoryIndex
                    )
                }
            }

            if let toast = appState.toastMessage {
                ToastView(message: toast)
                    .padding(.bottom, 20)
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
            appState.clipboardService.pollNow()
            if selectedHistoryIndex == nil, !appState.historyStore.items.isEmpty {
                selectedHistoryIndex = 0
            }
        }
    }

    private func moveSelection(delta: Int) {
        let count = appState.historyStore.items.count
        guard count > 0 else { return }
        let current = selectedHistoryIndex ?? 0
        selectedHistoryIndex = max(0, min(count - 1, current + delta))
    }

    private func pasteSelectedItem() {
        guard let index = selectedHistoryIndex,
              index < appState.historyStore.items.count else { return }
        appState.pasteItem(appState.historyStore.items[index], panelController: panelController)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 1) {
                Text("HotSlot")
                    .font(.headline)
                Text("Portapapeles inteligente")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text("⌘⇧V")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.quaternary.opacity(0.6)))

            Button {
                panelController.hide()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.quaternary.opacity(0.7)))
            }
            .buttonStyle(.plain)
            .help("Cerrar (Esc)")
        }
        .padding(.horizontal, HotSlotDesign.horizontalPadding)
        .padding(.vertical, 14)
    }
}
