import KeyboardShortcuts
import SwiftUI

struct HotkeysSettingsView: View {
    @State private var showResetConfirmation = false
    @State private var issues: [ShortcutConflict.Issue] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SlotsSpace.m) {
                if !issues.isEmpty {
                    infoCard(
                        icon: "exclamationmark",
                        text: "Algunos atajos coinciden con otro de \(BrandDisplay.name) o con macOS (\(issues.map(\.shortcutDescription).joined(separator: ", "))). No los cambiamos solos: grabá uno distinto desde el panel o restaurá los valores por defecto.",
                        tint: SlotsColor.naranja
                    )
                }

                card {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Abrir / cerrar panel")
                                .font(SlotsFont.textoUI.weight(.semibold))
                            Text("Slots a la izquierda, historial a la derecha")
                                .font(SlotsFont.etiqueta)
                                .foregroundStyle(SlotsColor.textoSecundario)
                        }
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .togglePanel)
                    }
                }

                card {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Atajos de cada slot")
                            .font(SlotsFont.textoUI.weight(.semibold))
                        Text("Se editan desde el panel: pasá el mouse por un slot y hacé clic en su atajo. Pegar usa ⌘⇧ y guardar usa ⌘⌃ más A, S, D, Q, W.")
                            .font(SlotsFont.etiqueta)
                            .foregroundStyle(SlotsColor.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                infoCard(
                    icon: "info",
                    text: "Si un atajo no responde, otra app puede estar usándolo. Grabá uno nuevo o restaurá los valores por defecto.",
                    tint: SlotsColor.tinta
                )

                HStack {
                    Spacer()
                    Button {
                        showResetConfirmation = true
                    } label: {
                        Text("Restaurar atajos")
                            .font(SlotsFont.textoUI)
                            .foregroundStyle(.white)
                            .padding(.horizontal, SlotsSpace.l)
                            .frame(height: 44)
                            .background(Capsule(style: .continuous).fill(SlotsColor.tinta))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, SlotsSpace.l)
            .padding(.bottom, SlotsSpace.l)
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
        .confirmationDialog(
            "¿Restaurar todos los atajos?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Restaurar", role: .destructive) {
                KeyboardShortcuts.Name.resetAllToDefaults()
                refreshIssues()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se aplicarán los atajos por defecto (⌘⇧V, pegar ⌘⇧A S D Q W, guardar ⌘⌃ iguales).")
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(SlotsSpace.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous)
                    .fill(Color.white.opacity(0.85))
            }
    }

    private func infoCard(icon: String, text: String, tint: Color) -> some View {
        HStack(alignment: .center, spacing: SlotsSpace.s) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(tint))
            Text(text)
                .font(SlotsFont.etiqueta)
                .foregroundStyle(SlotsColor.textoTerciario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SlotsSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous)
                .fill(Color.white.opacity(0.55))
        }
    }

    private func refreshIssues() {
        issues = ShortcutConflict.issues()
    }
}
