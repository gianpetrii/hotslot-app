import SwiftUI

/// Cabecera del panel Mac (biblioteca + buscador) según handoff Main.
struct PanelHeaderBlock: View {
    @Bindable var appState: AppState
    let panelController: PanelController
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool

    private var libraryName: String {
        appState.libraryWorkspace.activeLibrary?.name ?? BrandDisplay.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SlotsSpace.m) {
            HStack(alignment: .firstTextBaseline, spacing: SlotsSpace.m) {
                Text(libraryName)
                    .font(SlotsFont.tituloPantalla(true))
                    .foregroundStyle(SlotsColor.tinta)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Button {
                    appState.openSettings?()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(SlotsColor.textoSecundario)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle()
                                .fill(SlotsColor.teclaFondo)
                        }
                }
                .buttonStyle(.plain)
                .help("Ajustes")

                Button {
                    panelController.hide(animated: true)
                    appState.isPanelVisible = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SlotsColor.textoSecundario)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle()
                                .fill(SlotsColor.teclaFondo)
                        }
                }
                .buttonStyle(.plain)
                .help("Cerrar panel")
                .keyboardShortcut(.escape, modifiers: [])
            }

            PanelSearchHeader(
                searchText: $searchText,
                isSearchFocused: $isSearchFocused,
                onOpenSettings: { appState.openSettings?() },
                onOpenTour: { appState.openOnboarding?() },
                onOpenLicense: { appState.openLicenseSettings() },
                onQuit: { NSApp.terminate(nil) }
            )
            .padding(.horizontal, -HotSlotDesign.horizontalPadding)
        }
        .padding(.horizontal, HotSlotDesign.horizontalPadding)
        .padding(.top, SlotsSpace.l)
        .padding(.bottom, SlotsSpace.s)
        .background(WindowDragHandle())
    }
}
