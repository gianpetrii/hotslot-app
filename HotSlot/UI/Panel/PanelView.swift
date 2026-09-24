import SwiftUI

struct PanelView: View {
    @Bindable var appState: AppState
    let panelController: PanelController
    @State private var searchText = ""
    @State private var keyboardHighlightIndex: Int?
    @State private var showHeader = false
    @State private var showBody = false
    @FocusState private var isSearchFocused: Bool

    private var filteredItems: [ClipItem] {
        appState.historyStore.items.filter { $0.matchesSearch(searchText) }
    }

    private let listAnimation = Animation.spring(response: 0.34, dampingFraction: 0.82)
    private let bodyRevealAnimation = Animation.spring(response: 0.46, dampingFraction: 0.76)

    var body: some View {
        ZStack(alignment: .bottom) {
            PanelChrome {
                VStack(spacing: 0) {
                    PanelSearchHeader(
                        searchText: $searchText,
                        isSearchFocused: $isSearchFocused,
                        onOpenSettings: { appState.openSettings?() },
                        onClose: { panelController.hide(animated: true) }
                    )
                    .opacity(showHeader ? 1 : 0)
                    .offset(y: showHeader ? 0 : -6)

                    VStack(spacing: 0) {
                        SlotGridView(appState: appState, panelController: panelController)
                            .padding(.bottom, HotSlotDesign.sectionSpacing)

                        Divider().opacity(0.22)
                            .padding(.horizontal, HotSlotDesign.horizontalPadding)

                        HistoryListView(
                            historyStore: appState.historyStore,
                            items: filteredItems,
                            isSearching: !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            onPaste: { item in
                                appState.pasteItem(item, panelController: panelController)
                            },
                            keyboardHighlightIndex: $keyboardHighlightIndex
                        )
                        .padding(.top, HotSlotDesign.sectionSpacing)
                    }
                    .frame(height: showBody ? HotSlotDesign.panelBodyHeight : 0, alignment: .top)
                    .clipped()
                    .opacity(showBody ? 1 : 0)
                }
            }

            if let toast = appState.toastMessage {
                ToastView(message: toast)
                    .padding(.bottom, 18)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
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
        .onKeyPress(.escape) {
            panelController.hide(animated: true)
            return .handled
        }
        .onAppear {
            appState.clipboardService.pollNow()
            keyboardHighlightIndex = nil
            showHeader = false
            showBody = false

            withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                showHeader = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(bodyRevealAnimation) {
                    showBody = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }
        }
        .onDisappear {
            searchText = ""
            keyboardHighlightIndex = nil
            showHeader = false
            showBody = false
        }
        .onChange(of: searchText) { _, _ in
            withAnimation(listAnimation) {
                keyboardHighlightIndex = nil
            }
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
