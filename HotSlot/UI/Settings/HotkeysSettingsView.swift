import KeyboardShortcuts
import SwiftUI

struct HotkeysSettingsView: View {
    @State private var showResetConfirmation = false
    @State private var issues: [ShortcutConflict.Issue] = []

    var body: some View {
        Form {
            if !issues.isEmpty {
                Section {
                    Label {
                        Text("Algunos atajos coinciden con otro de HotSlot o con macOS. No los cambiamos solos: grabá uno distinto o restaurá los valores por defecto.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    .font(.callout)
                }
            }

            Section("Panel") {
                shortcutRow("Abrir / cerrar panel", name: .togglePanel)
            }

            Section("Pegar desde slot") {
                ForEach(1...SlotStore.slotCount, id: \.self) { index in
                    shortcutRow("Slot \(index)", name: pasteSlotName(index))
                }
            }

            Section("Guardar en slot") {
                ForEach(1...SlotStore.slotCount, id: \.self) { index in
                    shortcutRow("Slot \(index)", name: copyToSlotName(index))
                }
            }

            Section {
                Text("Si un atajo no responde, otra app puede estar usándolo. HotSlot no puede listar esas apps: grabá uno nuevo.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Restaurar atajos por defecto", role: .destructive) {
                    showResetConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .padding()
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

    private func shortcutRow(_ label: String, name: KeyboardShortcuts.Name) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                KeyboardShortcuts.Recorder(for: name)
            }
            if let issue = issues.first(where: { $0.id == name.rawValue }) {
                Text("\(issue.shortcutDescription) · \(issue.message)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func refreshIssues() {
        issues = ShortcutConflict.issues()
    }

    private func pasteSlotName(_ index: Int) -> KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.pasteSlotNames[index - 1]
    }

    private func copyToSlotName(_ index: Int) -> KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.copyToSlotNames[index - 1]
    }
}
