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

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let listAnimation = Animation.spring(response: 0.34, dampingFraction: 0.82)

    var body: some View {
        VStack(spacing: HotSlotDesign.panelHintOutsideGap) {
            ZStack(alignment: .topLeading) {
                PanelChrome(revealWidth: revealWidth, revealHeight: revealHeight) {
                    VStack(spacing: HotSlotDesign.panelSectionGap) {
                        PanelHeaderBlock(
                            appState: appState,
                            panelController: panelController,
                            searchText: $searchText,
                            isSearchFocused: $isSearchFocused
                        )

                        HStack(alignment: .top, spacing: HotSlotDesign.panelBodyGap) {
                            SlotGridView(
                                appState: appState,
                                panelController: panelController,
                                searchText: searchText
                            )
                            .padding(.top, HotSlotDesign.panelColumnTopInset)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                            HistoryListView(
                                historyStore: appState.historyStore,
                                items: filteredItems,
                                isSearching: !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                onPaste: { item in
                                    appState.pasteItem(item, panelController: panelController)
                                },
                                keyboardHighlightIndex: $keyboardHighlightIndex
                            )
                            .padding(.top, HotSlotDesign.panelColumnTopInset)
                            .frame(width: HotSlotDesign.historyColumnWidth)
                        }
                        .padding(.horizontal, HotSlotDesign.horizontalPadding)
                        .frame(maxHeight: .infinity)
                        .opacity(appState.panelBodyRevealed ? 1 : 0.35)

                        PanelLibraryBar(appState: appState)
                    }
                    .frame(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelHeight, alignment: .top)
                    .clipped()
                }
            }
            .frame(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelHeight, alignment: .topLeading)

            panelShortcutHint
        }
        .frame(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelWindowHeight, alignment: .top)
        .overlay(alignment: .bottom) {
            if let toast = appState.toastMessage {
                ToastView(message: toast)
                    .padding(.bottom, HotSlotDesign.panelHintOutsideHeight + 8)
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
            pasteFirstSearchResult()
            return .handled
        }
        .onKeyPress(.escape) {
            if isSearching {
                searchText = ""
                keyboardHighlightIndex = nil
                isSearchFocused = true
                return .handled
            }
            panelController.hide(animated: true)
            appState.isPanelVisible = false
            return .handled
        }
        .onKeyPress(keys: [.init("f")], phases: .down) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            isSearchFocused = true
            return .handled
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

    private var panelShortcutHint: some View {
        Text("Clic para pegar · Arrastrá para guardar · Esc para cerrar")
            .font(SlotsFont.textoUI)
            .foregroundStyle(SlotsColor.textoTerciario)
            .frame(maxWidth: .infinity, minHeight: HotSlotDesign.panelHintOutsideHeight)
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

    private func pasteFirstSearchResult() {
        if let index = keyboardHighlightIndex, index < filteredItems.count {
            appState.pasteItem(filteredItems[index], panelController: panelController)
            return
        }
        if isSearching {
            if let slot = appState.slotStore.slots.first(where: { $0.matchesSearch(searchText) && $0.content != nil }) {
                appState.pasteSlot(index: slot.index, panelController: panelController)
                return
            }
            if let first = filteredItems.first {
                appState.pasteItem(first, panelController: panelController)
                return
            }
            return
        }
        pasteKeyboardHighlightedItem()
    }
}
