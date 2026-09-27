import SwiftUI

struct ClipRowView: View {
    let item: ClipItem
    let isKeyboardHighlighted: Bool
    let onPaste: () -> Void
    let onTogglePin: () -> Void
    @State private var isHovering = false
    @State private var isExpanded = false
    @State private var expandTask: Task<Void, Never>?

    private let expandAnimation = Animation.spring(response: 0.32, dampingFraction: 0.92)

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack(alignment: .topLeading) {
                rowBody
                Color.clear
                    .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .onTapGesture(perform: onPaste)
            .draggable(PanelDragPayload.historyItem(id: item.id)) {
                Text(item.content.previewText)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .padding(8)
                    .frame(maxWidth: 180, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if item.isPinned || isHovering {
                PinButton(isPinned: item.isPinned, action: onTogglePin)
                    .padding(.top, 2)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.82, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.82, anchor: .top).combined(with: .opacity)
                    ))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: HotSlotDesign.rowCornerRadius, style: .continuous)
                .fill(backgroundFill)
        }
        .onHover { hovering in
            isHovering = hovering
            expandTask?.cancel()
            if hovering {
                expandTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(HotSlotDesign.hoverExpandDelay * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    withAnimation(expandAnimation) {
                        isExpanded = true
                    }
                }
            } else {
                withAnimation(expandAnimation) {
                    isExpanded = false
                }
            }
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isKeyboardHighlighted)
        .animation(.easeOut(duration: 0.15), value: item.isPinned)
        .onDisappear {
            expandTask?.cancel()
            isExpanded = false
            isHovering = false
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Clic para pegar. Arrastrá para guardar en un slot.")
    }

    @ViewBuilder
    private var rowBody: some View {
        VStack(alignment: .leading, spacing: 5) {
            switch item.content {
            case .image(let fileName):
                ClipThumbnailView(fileName: fileName, style: .row, isExpanded: isExpanded)
            case .text(let string):
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                Text(trimmed)
                    .font(HotSlotTypography.rowPrimary)
                    .foregroundStyle(.primary)
                    .lineLimit(isExpanded ? 12 : 3)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(
                        height: textUsesExpand ? textPreviewHeight : nil,
                        alignment: .topLeading
                    )
                    .clipped()
            }

            Text(item.metadataLine())
                .font(HotSlotTypography.rowSecondary)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var textUsesExpand: Bool {
        guard case .text(let string) = item.content else { return false }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 120 || trimmed.contains("\n")
    }

    private var textPreviewHeight: CGFloat {
        isExpanded ? HotSlotDesign.textRowPreviewHeightExpanded : HotSlotDesign.textRowPreviewHeight
    }

    private var backgroundFill: Color {
        if isKeyboardHighlighted { return Color.accentColor.opacity(0.12) }
        if item.isPinned { return Color.accentColor.opacity(0.05) }
        if isHovering { return Color.primary.opacity(0.05) }
        return Color.clear
    }
}

private struct PinButton: View {
    let isPinned: Bool
    let action: () -> Void

    var body: some View {
        PanelGlyphButton(
            systemImage: isPinned ? "pin.fill" : "pin",
            foreground: isPinned ? Color.accentColor : .secondary,
            help: isPinned ? "Desfijar" : "Fijar arriba",
            action: action
        )
    }
}
