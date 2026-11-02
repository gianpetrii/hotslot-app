import SwiftUI

/// Pills de bibliotecas + «Guardar portapapeles» (handoff `Main.html`).
struct PanelLibraryBar: View {
    @Bindable var appState: AppState

    private var libraries: [Library] {
        appState.libraryWorkspace.workspace.libraries.sorted { $0.order < $1.order }
    }

    private var activeId: UUID {
        appState.libraryWorkspace.workspace.activeLibraryId
    }

    var body: some View {
        HStack(spacing: SlotsSpace.m) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SlotsSpace.s) {
                    ForEach(libraries) { library in
                        libraryPill(library)
                    }
                    addLibraryButton
                }
            }

            saveClipboardButton
        }
        .padding(.horizontal, HotSlotDesign.horizontalPadding)
    }

    private func libraryPill(_ library: Library) -> some View {
        let isActive = library.id == activeId
        let count = appState.libraryWorkspace.filledSlotCount(in: library.id)

        return Button {
            guard library.id != activeId else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                appState.switchLibrary(to: library.id)
            }
        } label: {
            HStack(spacing: SlotsSpace.s) {
                Text(library.name)
                    .font(SlotsFont.textoUI)
                countBadge(count: count, isActive: isActive)
            }
            .padding(.leading, 20)
            .padding(.trailing, SlotsSpace.s)
            .frame(height: SlotsRadius.controlAlto)
            .background {
                Capsule(style: .continuous)
                    .fill(isActive ? SlotsColor.tinta : Color.white.opacity(0.85))
            }
            .foregroundStyle(isActive ? Color.white : SlotsColor.tinta)
        }
        .buttonStyle(.plain)
    }

    private func countBadge(count: Int, isActive: Bool) -> some View {
        Text("\(count)")
            .font(SlotsFont.etiqueta)
            .foregroundStyle(isActive ? Color.white : SlotsColor.tinta)
            .frame(minWidth: 26, minHeight: 26)
            .background {
                Circle()
                    .fill(isActive ? SlotsColor.naranja : Color.black.opacity(0.07))
            }
    }

    private var addLibraryButton: some View {
        Button {
            appState.isNewLibraryFormPresented = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SlotsColor.tinta)
                .frame(width: SlotsRadius.controlAlto, height: SlotsRadius.controlAlto)
                .background {
                    Circle()
                        .strokeBorder(Color.black.opacity(0.28), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
        }
        .buttonStyle(.plain)
        .help("Nueva biblioteca")
    }

    private var saveClipboardButton: some View {
        Button {
            appState.saveClipboardFromPanel()
        } label: {
            HStack(spacing: 0) {
                Text("Guardar portapapeles")
                    .font(SlotsFont.textoUI)
                    .foregroundStyle(.white)
                    .padding(.leading, 20)
                    .padding(.trailing, 14)

                Text("›")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                    }
                    .padding(.trailing, 6)
            }
            .frame(height: SlotsRadius.controlAlto)
            .background {
                Capsule(style: .continuous)
                    .fill(SlotsColor.cardOscura)
            }
        }
        .buttonStyle(.plain)
        .help("Guarda el portapapeles en el primer slot vacío")
    }
}
