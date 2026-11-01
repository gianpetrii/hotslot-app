import SwiftUI

/// Pills de bibliotecas (Trabajo · Personal · …) en la base del panel.
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
                .padding(.vertical, 4)
            }

            Button {
                appState.saveClipboardFromPanel()
            } label: {
                Text("Guardar portapapeles")
                    .font(SlotsFont.etiqueta)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background {
                        Capsule(style: .continuous)
                            .fill(SlotsColor.tinta)
                    }
            }
            .buttonStyle(.plain)
            .help("Guarda el portapapeles en el primer slot vacío")
        }
        .padding(.horizontal, HotSlotDesign.horizontalPadding)
        .frame(height: HotSlotDesign.panelFooterHeight)
        .background(SlotsColor.papel)
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
            HStack(spacing: 6) {
                Text(library.name)
                    .font(SlotsFont.etiqueta)
                Text("\(count)")
                    .font(SlotsFont.etiqueta)
                    .foregroundStyle(isActive ? SlotsColor.naranja : SlotsColor.textoSecundario)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(isActive ? SlotsColor.tinta : SlotsColor.teclaFondo)
            }
            .foregroundStyle(isActive ? Color.white : SlotsColor.textoTerciario)
        }
        .buttonStyle(.plain)
    }

    private var addLibraryButton: some View {
        Button {
            newLibraryName = ""
            showNewLibrarySheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SlotsColor.textoSecundario)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .strokeBorder(SlotsColor.linea, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
        }
        .buttonStyle(.plain)
        .help("Nueva biblioteca")
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
