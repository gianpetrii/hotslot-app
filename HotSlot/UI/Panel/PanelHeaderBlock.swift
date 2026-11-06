import SwiftUI

/// Cabecera del panel Mac (handoff `Main.html`: título + buscador + filtros + cerrar).
struct PanelHeaderBlock: View {
    @Bindable var appState: AppState
    let panelController: PanelController
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    @State private var isLibraryTitleHovering = false
    @State private var isEditingLibraryName = false
    @State private var libraryNameDraft = ""
    @FocusState private var isLibraryNameFocused: Bool

    private var libraryName: String {
        appState.libraryWorkspace.activeLibrary?.name ?? BrandDisplay.name
    }

    var body: some View {
        HStack(alignment: .center, spacing: SlotsSpace.l) {
            libraryTitleBlock
                .frame(maxWidth: .infinity, minHeight: SlotsRadius.controlAlto, alignment: .leading)

            HStack(spacing: SlotsSpace.s) {
                panelSearchField
                panelCircleButton(
                    systemImage: "slider.horizontal.3",
                    size: SlotsRadius.controlAlto,
                    help: "Ajustes"
                ) {
                    appState.openSettings?()
                }
                panelCircleButton(
                    systemImage: "xmark",
                    size: SlotsRadius.controlAlto,
                    iconSize: 14,
                    help: "Cerrar panel"
                ) {
                    panelController.hide(animated: true)
                    appState.isPanelVisible = false
                }
            }
        }
        .padding(.horizontal, HotSlotDesign.horizontalPadding)
        .padding(.top, SlotsSpace.xl)
        .background(WindowDragHandle())
        .onChange(of: appState.librarySwitchRevision) { _, _ in
            cancelLibraryRename()
        }
    }

    private var libraryTitleBlock: some View {
        HStack(alignment: .center, spacing: 8) {
            if isEditingLibraryName {
                TextField("", text: $libraryNameDraft, prompt: Text("Nombre"))
                    .textFieldStyle(.plain)
                    .font(SlotsFont.tituloPantalla(false))
                    .foregroundStyle(SlotsColor.tinta)
                    .focused($isLibraryNameFocused)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(SlotsColor.naranja.opacity(0.7), lineWidth: 1.5)
                    }
                    .onSubmit { commitLibraryRename() }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                Text(libraryName)
                    .font(SlotsFont.tituloPantalla(false))
                    .foregroundStyle(SlotsColor.tinta)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .transition(.opacity)
            }

            Button(action: beginLibraryRename) {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SlotsColor.textoSecundario)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Renombrar biblioteca")
            .opacity(isLibraryTitleHovering && !isEditingLibraryName ? 1 : 0)
            .allowsHitTesting(isLibraryTitleHovering && !isEditingLibraryName)

            Spacer(minLength: 0)
        }
        .frame(minHeight: SlotsRadius.controlAlto, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { isLibraryTitleHovering = $0 }
        .animation(.easeOut(duration: 0.14), value: isLibraryTitleHovering)
        .animation(HotSlotDesign.titleEditAnimation, value: isEditingLibraryName)
        .highPriorityGesture(
            TapGesture().onEnded {
                guard isLibraryTitleHovering, !isEditingLibraryName else { return }
                beginLibraryRename()
            }
        )
        .onChange(of: isEditingLibraryName) { _, editing in
            if editing {
                libraryNameDraft = libraryName
                DispatchQueue.main.async {
                    isLibraryNameFocused = true
                }
            }
        }
        .onChange(of: isLibraryNameFocused) { wasFocused, focused in
            if wasFocused, !focused, isEditingLibraryName {
                commitLibraryRename()
            }
        }
        .onChange(of: appState.inlineEditSession) { _, _ in
            guard isEditingLibraryName else { return }
            if appState.inlineEditShouldSave {
                commitLibraryRename()
            } else {
                cancelLibraryRename()
            }
        }
    }

    private func beginLibraryRename() {
        guard appState.libraryWorkspace.activeLibrary != nil else { return }
        appState.beginInlineEdit()
        libraryNameDraft = libraryName
        withAnimation(HotSlotDesign.titleEditAnimation) {
            isEditingLibraryName = true
        }
    }

    private func commitLibraryRename() {
        guard isEditingLibraryName else { return }
        let trimmed = libraryNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let library = appState.libraryWorkspace.activeLibrary else {
            cancelLibraryRename()
            return
        }
        if trimmed != library.name {
            appState.renameLibrary(id: library.id, name: trimmed)
        }
        withAnimation(HotSlotDesign.titleEditAnimation) {
            isEditingLibraryName = false
        }
        isLibraryNameFocused = false
        appState.isInlineEditing = false
    }

    private func cancelLibraryRename() {
        guard isEditingLibraryName else { return }
        withAnimation(HotSlotDesign.titleEditAnimation) {
            isEditingLibraryName = false
        }
        isLibraryNameFocused = false
        libraryNameDraft = ""
        appState.isInlineEditing = false
    }

    private var panelSearchField: some View {
        HStack(spacing: SlotsSpace.s) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 32, height: 32)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SlotsColor.tinta)
            }

            TextField("Buscar en slots e historial", text: $searchText)
                .textFieldStyle(.plain)
                .font(SlotsFont.textoUI)
                .focused($isSearchFocused)

            Text("⌘F")
                .font(SlotsFont.etiqueta)
                .foregroundStyle(SlotsColor.textoSecundario)
                .padding(.horizontal, SlotsSpace.s)
                .padding(.vertical, SlotsSpace.xs)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.06))
                }
        }
        .padding(.leading, SlotsSpace.s)
        .padding(.trailing, SlotsSpace.s)
        .frame(width: HotSlotDesign.panelSearchFieldWidth, height: SlotsRadius.controlAlto)
        .background {
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.6))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.8), lineWidth: 1)
                }
        }
    }

    private func panelCircleButton(
        systemImage: String,
        size: CGFloat,
        iconSize: CGFloat = 18,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(SlotsColor.tinta)
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(Color.black.opacity(0.07))
                }
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
