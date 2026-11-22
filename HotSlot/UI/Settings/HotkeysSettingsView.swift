import KeyboardShortcuts
import SwiftUI

struct HotkeysSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var issues: [ShortcutConflict.Issue] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !issues.isEmpty {
                    SettingsNote(
                        text: "Algunos atajos coinciden con otro de \(BrandDisplay.name) o con macOS (\(issues.map(\.shortcutDescription).joined(separator: ", "))). No los cambiamos solos: grabá uno distinto desde el panel o restaurá los valores por defecto."
                    )
                }

                SettingsCard {
                    SettingsRow(
                        title: "Abrir / cerrar panel",
                        detail: "Slots a la izquierda, historial a la derecha"
                    ) {
                        KeyboardShortcuts.Recorder(for: .togglePanel)
                    }
                    SettingsRow(
                        title: "Atajos de cada slot",
                        detail: "Se editan desde el panel: pasá el mouse por un slot y hacé clic en su atajo. Pegar usa ⌘⇧ y guardar usa ⌘⌃ más A, S, D, Q, W."
                    ) {
                        EmptyView()
                    }
                    SettingsRow(title: "Restaurar atajos", destructive: true) {
                        SettingsPillButton(title: "Restaurar") {
                            appState.confirm?(AppConfirmation(
                                title: "¿Restaurar todos los atajos?",
                                message: "Se aplicarán los atajos por defecto (⌘⇧V, pegar ⌘⇧A S D Q W, guardar ⌘⌃ iguales).",
                                confirmTitle: "Restaurar",
                                destructive: true
                            ) {
                                KeyboardShortcuts.Name.resetAllToDefaults()
                                refreshIssues()
                            })
                        }
                    }
                }

                SettingsNote(
                    text: "Si un atajo no responde, otra app puede estar usándolo. Grabá uno nuevo o restaurá los valores por defecto."
                )
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(SlotsColor.tinta)
        .onAppear(perform: refreshIssues)
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange")
            )
        ) { _ in
            refreshIssues()
        }
    }

    private func refreshIssues() {
        issues = ShortcutConflict.issues()
    }
}
