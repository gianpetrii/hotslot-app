import SwiftUI

/// Cabecera del panel Mac (handoff `Main.html`: título + buscador + filtros + cerrar).
struct PanelHeaderBlock: View {
    @Bindable var appState: AppState
    let panelController: PanelController
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool

    private var libraryName: String {
        appState.libraryWorkspace.activeLibrary?.name ?? BrandDisplay.name
    }

    var body: some View {
        HStack(alignment: .top, spacing: SlotsSpace.l) {
            Text(libraryName)
                .font(SlotsFont.tituloPantalla(false))
                .foregroundStyle(SlotsColor.tinta)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(.top, 4)

            Spacer(minLength: 8)

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
