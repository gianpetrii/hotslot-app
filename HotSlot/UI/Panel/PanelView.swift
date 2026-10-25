import SwiftUI

struct PanelView: View {
    @Bindable var appState: AppState
    let panelController: PanelController
    @State private var searchText = ""
    @State private var keyboardHighlightIndex: Int?
    @State private var revealWidth = HotSlotDesign.panelWidth
    @State private var revealHeight = HotSlotDesign.panelHeight
    @State private var unfoldGeneration = 0
    @FocusState private var isSearchFocused: Bool

    private var filteredItems: [ClipItem] {
        appState.historyStore.items.filter { $0.matchesSearch(searchText) }
    }

    private let listAnimation = Animation.spring(response: 0.34, dampingFraction: 0.82)

    var body: some View {
        ZStack(alignment: .topLeading) {
            PanelChrome(revealWidth: revealWidth, revealHeight: revealHeight) {
                VStack(spacing: 0) {
                    PanelSearchHeader(
                        searchText: $searchText,
                        isSearchFocused: $isSearchFocused,
                        onOpenSettings: { appState.openSettings?() },
                        onOpenTour: { appState.openOnboarding?() },
                        onClose: { panelController.hide(animated: true) }
                    )

                    HStack(alignment: .top, spacing: 0) {
                        SlotGridView(appState: appState, panelController: panelController)
                            .frame(width: HotSlotDesign.slotsColumnWidth)

                        Rectangle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 1)
                            .padding(.vertical, 10)

                        HistoryListView(
                            historyStore: appState.historyStore,
                            items: filteredItems,
                            isSearching: !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            onPaste: { item in
                                appState.pasteItem(item, panelController: panelController)
                            },
                            keyboardHighlightIndex: $keyboardHighlightIndex
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(.bottom, 8)
                    .opacity(appState.panelBodyRevealed ? 1 : 0.35)
                }
            }
        }
        .frame(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelHeight, alignment: .topLeading)
        .overlay(alignment: .bottom) {
            if let toast = appState.toastMessage {
                ToastView(message: toast)
                    .padding(.bottom, 18)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.easeOut(duration: 0.2), value: appState.panelBodyRevealed)
        .animation(.spring(response: 0.3, dampingFraction: 0.88), value: appState.toastMessage)
        .animation(listAnimation, value: filteredItems.map(\.id))
        .onKeyPress(.upArrow) {
            moveKeyboardHighlight(delta: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveKeyboardHighlight(delta: 1)
            return .handled
        }
        .onKeyPress(.return) {
            pasteKeyboardHighlightedItem()
            return .handled
        }
        .onExitCommand {
            panelController.hide(animated: true)
        }
        .onChange(of: appState.isPanelVisible) { _, visible in
            if visible {
                playOpenAnimation()
            } else {
                unfoldGeneration += 1
            }
        }
        .onAppear {
            if appState.isPanelVisible {
                playOpenAnimation()
            }
        }
        .onChange(of: searchText) { _, _ in
            withAnimation(listAnimation) {
                keyboardHighlightIndex = nil
            }
        }
        .onDisappear {
            searchText = ""
            keyboardHighlightIndex = nil
        }
        .environment(appState)
    }

    private func playOpenAnimation() {
        unfoldGeneration += 1
        let generation = unfoldGeneration
        keyboardHighlightIndex = nil
        appState.panelBodyRevealed = false
        revealWidth = HotSlotDesign.openSquareSize
        revealHeight = HotSlotDesign.openSquareSize

        DispatchQueue.main.async {
            guard generation == unfoldGeneration else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                revealWidth = HotSlotDesign.panelWidth
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + HotSlotDesign.openRightDuration) {
            guard generation == unfoldGeneration else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                revealHeight = HotSlotDesign.panelHeight
                appState.panelBodyRevealed = true
            }
            isSearchFocused = true
        }

        // Si el spring no llega a disparar el segundo paso, el panel no puede quedar vacío.
        DispatchQueue.main.asyncAfter(deadline: .now() + HotSlotDesign.openRightDuration + 0.8) {
            guard generation == unfoldGeneration else { return }
            revealWidth = HotSlotDesign.panelWidth
            revealHeight = HotSlotDesign.panelHeight
            appState.panelBodyRevealed = true
        }
    }

    private func moveKeyboardHighlight(delta: Int) {
        let count = filteredItems.count
        guard count > 0 else { return }
        let current = keyboardHighlightIndex ?? 0
        keyboardHighlightIndex = max(0, min(count - 1, current + delta))
    }

    private func pasteKeyboardHighlightedItem() {
        guard let index = keyboardHighlightIndex,
              index < filteredItems.count else { return }
        appState.pasteItem(filteredItems[index], panelController: panelController)
    }
}
