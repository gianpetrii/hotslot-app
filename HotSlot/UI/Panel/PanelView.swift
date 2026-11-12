import SwiftUI

struct PanelView: View {
    @Bindable var appState: AppState
    let panelController: PanelController
    @State private var searchText = ""
    @State private var keyboardHighlightIndex: Int?
    @State private var revealWidth = HotSlotDesign.panelWidth
    @State private var revealHeight = HotSlotDesign.panelHeight
    @State private var unfoldGeneration = 0
    @State private var newLibraryName = ""
    @State private var renameLibraryName = ""
    @State private var dontAskBeforeLibraryDelete = false
    @FocusState private var isSearchFocused: Bool

    private var filteredItems: [ClipItem] {
        appState.historyStore.items.filter { $0.matchesSearch(searchText) }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let listAnimation = Animation.spring(response: 0.34, dampingFraction: 0.82)

    static let coordinateSpaceName = "panelRoot"

    private var showsLibraryTrash: Bool {
        guard let drag = appState.libraryDrag, !drag.isSettling else { return false }
        return appState.libraryWorkspace.workspace.libraries.count > 1
    }

    var body: some View {
        ZStack {
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
                            .id("header-\(appState.librarySwitchRevision)")
                            .transition(.opacity.combined(with: .move(edge: .top)))

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
                            .id("body-\(appState.librarySwitchRevision)")
                            .transition(.opacity.combined(with: .scale(scale: 0.992)))

                            PanelLibraryBar(appState: appState)
                        }
                        .padding(.bottom, SlotsSpace.xl)
                        .frame(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelHeight, alignment: .top)
                    }
                }
                .frame(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelHeight, alignment: .topLeading)

                ZStack(alignment: .top) {
                    if showsLibraryTrash {
                        PanelFloatingLibraryTrash(appState: appState)
                            .frame(maxHeight: .infinity)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else {
                        panelShortcutHint
                            .transition(.opacity)
                    }
                }
                .frame(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelBottomBandHeight, alignment: .top)
            }
            .animation(.easeOut(duration: 0.18), value: showsLibraryTrash)
            .frame(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelWindowHeight, alignment: .top)

            panelModalLayer
        }
        .frame(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelWindowHeight, alignment: .top)
        .coordinateSpace(name: Self.coordinateSpaceName)
        .overlay(alignment: .topLeading) {
            floatingDraggedLibrary
        }
        .animation(.easeOut(duration: 0.12), value: appState.librarySwitchRevision)
        .animation(.easeOut(duration: 0.18), value: appState.isSaveClipboardSlotPickerPresented)
        .animation(.easeOut(duration: 0.18), value: appState.isNewLibraryFormPresented)
        .animation(.easeOut(duration: 0.18), value: appState.deleteLibraryConfirmation != nil)
        .animation(.easeOut(duration: 0.18), value: appState.renameLibraryTarget != nil)
        .overlay(alignment: .bottom) {
            if let toast = appState.toastMessage {
                ToastView(message: toast)
                    .padding(.bottom, HotSlotDesign.panelBottomBandHeight + 8)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.easeOut(duration: 0.12), value: appState.panelBodyRevealed)
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
            if appState.isNewLibraryFormPresented {
                appState.isNewLibraryFormPresented = false
                newLibraryName = ""
                return .handled
            }
            if appState.isSaveClipboardSlotPickerPresented {
                appState.isSaveClipboardSlotPickerPresented = false
                return .handled
            }
            if appState.deleteLibraryConfirmation != nil {
                appState.deleteLibraryConfirmation = nil
                return .handled
            }
            if appState.renameLibraryTarget != nil {
                appState.renameLibraryTarget = nil
                renameLibraryName = ""
                return .handled
            }
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
            appState.libraryDrag = nil
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
        .onChange(of: appState.isNewLibraryFormPresented) { _, presented in
            if presented { newLibraryName = "" }
        }
        .onChange(of: appState.renameLibraryTarget) { _, library in
            if let library { renameLibraryName = library.name }
        }
        .onDisappear {
            searchText = ""
            keyboardHighlightIndex = nil
        }
        .environment(appState)
    }

    @ViewBuilder
    private var floatingDraggedLibrary: some View {
        if let drag = appState.libraryDrag,
           let library = appState.libraryWorkspace.workspace.libraries.first(where: { $0.id == drag.libraryId }) {
            let overTrash = appState.floatingLibraryTrashTargeted
            LibraryPillLabel(
                name: library.name,
                count: appState.libraryWorkspace.filledSlotCount(in: library.id),
                isActive: library.id == appState.libraryWorkspace.workspace.activeLibraryId
            )
            .shadow(color: Color.black.opacity(drag.isSettling ? 0.04 : 0.18), radius: drag.isSettling ? 4 : 14, y: drag.isSettling ? 1 : 6)
            .scaleEffect(overTrash ? 0.6 : (drag.isSettling ? 1 : 1.04))
            .opacity(overTrash ? 0.75 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: overTrash)
            .position(
                x: drag.startFrame.midX + drag.translation.width,
                y: drag.startFrame.midY + drag.translation.height
            )
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var panelModalLayer: some View {
        if appState.isSaveClipboardSlotPickerPresented {
            PanelModalOverlay {
                appState.isSaveClipboardSlotPickerPresented = false
            } content: {
                SaveClipboardSlotPickerSheet(appState: appState)
            }
            .zIndex(100)
        } else if appState.isNewLibraryFormPresented {
            PanelModalOverlay {
                appState.isNewLibraryFormPresented = false
                newLibraryName = ""
            } content: {
                NewLibraryFormView(
                    name: $newLibraryName,
                    onCancel: {
                        appState.isNewLibraryFormPresented = false
                        newLibraryName = ""
                    },
                    onCreate: {
                        appState.createLibrary(named: newLibraryName)
                        appState.isNewLibraryFormPresented = false
                        newLibraryName = ""
                    }
                )
            }
            .zIndex(100)
        } else if let library = appState.deleteLibraryConfirmation {
            PanelModalOverlay {
                appState.deleteLibraryConfirmation = nil
            } content: {
                DeleteLibraryFormView(
                    libraryName: library.name,
                    dontAskAgain: $dontAskBeforeLibraryDelete,
                    onCancel: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            appState.deleteLibraryConfirmation = nil
                        }
                        dontAskBeforeLibraryDelete = false
                    },
                    onDelete: {
                        if dontAskBeforeLibraryDelete {
                            appState.setConfirmLibraryDelete(false)
                        }
                        withAnimation(.easeOut(duration: 0.2)) {
                            _ = appState.deleteLibrary(id: library.id)
                            appState.deleteLibraryConfirmation = nil
                        }
                        dontAskBeforeLibraryDelete = false
                    }
                )
            }
            .zIndex(100)
        } else if let library = appState.renameLibraryTarget {
            PanelModalOverlay {
                appState.renameLibraryTarget = nil
                renameLibraryName = ""
            } content: {
                RenameLibraryFormView(
                    name: $renameLibraryName,
                    onCancel: {
                        appState.renameLibraryTarget = nil
                        renameLibraryName = ""
                    },
                    onSave: {
                        appState.renameLibrary(id: library.id, name: renameLibraryName)
                        appState.renameLibraryTarget = nil
                        renameLibraryName = ""
                    }
                )
            }
            .zIndex(100)
        }
    }

    private var panelShortcutHint: some View {
        Text(appState.settings.clickItemAction == .copyToClipboard
             ? "Clic para copiar · ⌘V para pegar · Esc para cerrar"
             : "Clic para pegar · Arrastrá para guardar · Esc para cerrar")
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
            withAnimation(.spring(response: 0.2, dampingFraction: 0.86)) {
                revealWidth = HotSlotDesign.panelWidth
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + HotSlotDesign.openRightDuration) {
            guard generation == unfoldGeneration else { return }
            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                revealHeight = HotSlotDesign.panelHeight
                appState.panelBodyRevealed = true
            }
            isSearchFocused = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + HotSlotDesign.openRightDuration + 0.32) {
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
