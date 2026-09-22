import SwiftUI

struct SlotGridView: View {
    @Bindable var appState: AppState
    let panelController: PanelController

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Slots")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(appState.slotStore.slots) { slot in
                    SlotCardView(
                        slot: slot,
                        onPaste: {
                            appState.pasteSlot(index: slot.index, panelController: panelController)
                        },
                        onSaveFromClipboard: {
                            if let content = appState.clipboardService.currentContent() {
                                appState.slotStore.saveContent(index: slot.index, content: content)
                                appState.showToast("Guardado en \(slot.label)")
                            }
                        },
                        onClear: {
                            appState.slotStore.clearSlot(index: slot.index)
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

private struct SlotCardView: View {
    let slot: Slot
    let onPaste: () -> Void
    let onSaveFromClipboard: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(slot.index)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: slot.content == nil ? "square.dashed" : "square.fill")
                    .font(.caption2)
                    .foregroundStyle(slot.content == nil ? Color.secondary.opacity(0.5) : Color.accentColor)
            }

            Text(slot.label)
                .font(.caption)
                .lineLimit(1)

            if let content = slot.content {
                Text(content.previewText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("Vacío")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onPaste)
        .onTapGesture(count: 1) {
            onPaste()
        }
        .contextMenu {
            Button("Pegar") { onPaste() }
            Button("Guardar clipboard") { onSaveFromClipboard() }
            if slot.content != nil {
                Button("Limpiar", role: .destructive) { onClear() }
            }
        }
        .help("⌘⇧\(slot.index) para pegar")
    }
}
