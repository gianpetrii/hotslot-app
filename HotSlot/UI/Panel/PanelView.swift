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
                    Divider().opacity(0.25)
                    SlotGridView(appState: appState, panelController: panelController)
                        .padding(.vertical, HotSlotDesign.sectionSpacing)
                    Divider().opacity(0.25)
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
                    .padding(.bottom, 22)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: appState.toastMessage)
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
        HStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 2) {
                Text("HotSlot")
                    .font(HotSlotTypography.panelTitle)
                Text("Portapapeles inteligente")
                    .font(HotSlotTypography.panelSubtitle)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text("⌘⇧V")
                .font(HotSlotTypography.badge)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                        }
                }

            Button {
                panelController.hide(animated: true)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                            }
                    }
            }
            .buttonStyle(.plain)
            .help("Cerrar (Esc)")
        }
        .padding(.horizontal, HotSlotDesign.horizontalPadding)
        .padding(.vertical, 16)
    }
}
