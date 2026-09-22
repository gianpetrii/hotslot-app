import SwiftUI

struct SlotGridView: View {
    @Bindable var appState: AppState
    let panelController: PanelController

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: HotSlotDesign.sectionSpacing) {
            SectionHeader(title: "Slots")

            LazyVGrid(columns: columns, spacing: 10) {
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
            .padding(.horizontal, HotSlotDesign.horizontalPadding)
        }
    }
}

private struct SlotCardView: View {
    let slot: Slot
    let onPaste: () -> Void
    let onSaveFromClipboard: () -> Void
    let onClear: () -> Void
    @State private var isHovering = false

    private var hasContent: Bool { slot.content != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(slot.index)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(.quaternary.opacity(0.6)))
                Spacer()
                Image(systemName: hasContent ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.caption)
                    .foregroundStyle(hasContent ? Color.accentColor : Color.secondary.opacity(0.45))
            }

            Text(slot.label)
                .font(.caption.weight(.medium))
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
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .background {
            GlassCardBackground(isHighlighted: hasContent || isHovering)
        }
        .scaleEffect(isHovering ? 1.02 : 1)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .contentShape(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous))
        .onTapGesture { onPaste() }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Pegar") { onPaste() }
            Button("Guardar clipboard") { onSaveFromClipboard() }
            if hasContent {
                Button("Limpiar", role: .destructive) { onClear() }
            }
        }
        .help("⌘⇧\(slot.index) para pegar")
    }
}
