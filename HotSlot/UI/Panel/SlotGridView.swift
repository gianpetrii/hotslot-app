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
                    .frame(width: 20, height: 20)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                    }
                Spacer()
                Image(systemName: hasContent ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.caption)
                    .foregroundStyle(hasContent ? Color.accentColor : Color.secondary.opacity(0.45))
            }

            Text(slot.label)
                .font(HotSlotTypography.slotLabel)
                .lineLimit(1)

            if let content = slot.content {
                Text(content.previewText)
                    .font(HotSlotTypography.slotPreview)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("Vacío")
                    .font(HotSlotTypography.slotPreview)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background {
            GlassCardBackground(isHighlighted: hasContent || isHovering)
        }
        .scaleEffect(isHovering ? 1.03 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isHovering)
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
