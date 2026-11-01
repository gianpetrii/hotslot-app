import SwiftUI

/// Pills de bibliotecas + «Guardar portapapeles» (handoff `Main.html`).
struct PanelLibraryBar: View {
    @Bindable var appState: AppState
    @State private var showNewLibrarySheet = false
    @State private var newLibraryName = ""

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
        .padding(.vertical, SlotsSpace.xs)
        .sheet(isPresented: $appState.isSaveClipboardSlotPickerPresented) {
            SaveClipboardSlotPickerSheet(appState: appState)
        }
        .sheet(isPresented: $showNewLibrarySheet) {
            newLibrarySheet
        }
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
            newLibraryName = ""
            showNewLibrarySheet = true
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
            HStack(spacing: -6) {
                Text("Guardar portapapeles")
                    .font(SlotsFont.textoUI)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: SlotsRadius.controlAlto)
                    .background {
                        Capsule(style: .continuous)
                            .fill(SlotsColor.cardOscura)
                    }

                Text("›")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: SlotsRadius.controlAlto, height: SlotsRadius.controlAlto)
                    .background {
                        Circle()
                            .fill(SlotsColor.cardOscura)
                    }
            }
        }
        .buttonStyle(.plain)
        .help("Guarda el portapapeles en el primer slot vacío")
    }

    private var newLibrarySheet: some View {
        VStack(alignment: .leading, spacing: SlotsSpace.m) {
            Text("Nueva biblioteca")
                .font(SlotsFont.tituloCard)

            TextField("Nombre", text: $newLibraryName)
                .textFieldStyle(.roundedBorder)
                .font(SlotsFont.textoUI)

            HStack {
                Spacer()
                Button("Cancelar") { showNewLibrarySheet = false }
                Button("Crear biblioteca") {
                    appState.createLibrary(named: newLibraryName)
                    showNewLibrarySheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newLibraryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(SlotsSpace.l)
        .frame(width: 320)
    }
}
