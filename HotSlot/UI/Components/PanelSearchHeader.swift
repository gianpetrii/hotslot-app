import SwiftUI

/// Barra de búsqueda superior (estilo Clipboard nativo).
struct PanelSearchHeader: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let onOpenSettings: () -> Void
    let onOpenTour: () -> Void
    let onClose: () -> Void
    @State private var isEditingPanelShortcut = false
    @State private var isBadgeHovering = false

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Buscar en el historial", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(HotSlotTypography.searchField)
                    .focused($isSearchFocused)

                Button {
                    isEditingPanelShortcut = true
                } label: {
                    ShortcutBadge(name: .togglePanel, emphasized: isBadgeHovering)
                }
                .buttonStyle(.plain)
                .frame(width: HotSlotDesign.shortcutBadgeWidthRegular)
                .help("Clic para cambiar el atajo de abrir/cerrar el panel")
                .onHover { isBadgeHovering = $0 }
                .popover(isPresented: $isEditingPanelShortcut, arrowEdge: .bottom) {
                    PanelToggleShortcutPopover()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            }

            Menu {
                Button("Cómo usar \(BrandDisplay.name)") { onOpenTour() }
                Button("Ajustes…") { onOpenSettings() }
                Divider()
                Button("Cerrar panel") { onClose() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background {
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                            }
                    }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Más opciones")
        }
        .padding(.horizontal, HotSlotDesign.horizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(WindowDragHandle())
    }
}
