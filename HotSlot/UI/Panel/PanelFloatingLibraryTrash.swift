import SwiftUI

/// Tacho bajo el panel mientras se arrastra una biblioteca.
struct PanelFloatingLibraryTrash: View {
    @Bindable var appState: AppState

    private var isTargeted: Bool {
        appState.floatingLibraryTrashTargeted
    }

    var body: some View {
        Image(systemName: isTargeted ? "trash.fill" : "trash")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(isTargeted ? SlotsColor.naranja : SlotsColor.textoSecundario)
            .frame(width: 44, height: 44)
            .background {
                Circle()
                    .fill(isTargeted ? SlotsColor.cardOscura : Color.white.opacity(0.85))
                    .overlay {
                        Circle()
                            .strokeBorder(
                                isTargeted ? SlotsColor.naranja : Color.black.opacity(0.12),
                                lineWidth: isTargeted ? 2 : 1
                            )
                    }
                    .shadow(color: Color.black.opacity(isTargeted ? 0.22 : 0.08), radius: isTargeted ? 12 : 6, y: 4)
            }
            .scaleEffect(isTargeted ? 1.25 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.66), value: isTargeted)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { appState.libraryTrashFrame = geo.frame(in: .named(PanelView.coordinateSpaceName)) }
                        .onDisappear { appState.libraryTrashFrame = .zero }
                }
            }
            .accessibilityLabel("Tacho: soltá una biblioteca para eliminarla")
    }
}
