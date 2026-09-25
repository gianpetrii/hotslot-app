import SwiftUI

struct ClipRowView: View {
    let item: ClipItem
    let isKeyboardHighlighted: Bool
    let onPaste: () -> Void
    let onTogglePin: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onPaste) {
                rowBody
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(RoundedRectangle(cornerRadius: HotSlotDesign.rowCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)

            if item.isPinned || isHovering {
                PinButton(isPinned: item.isPinned, action: onTogglePin)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: HotSlotDesign.rowCornerRadius, style: .continuous)
                .fill(backgroundFill)
        }
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isKeyboardHighlighted)
        .animation(.easeOut(duration: 0.15), value: item.isPinned)
    }

    @ViewBuilder
    private var rowBody: some View {
        VStack(alignment: .leading, spacing: 5) {
            switch item.content {
            case .image(let fileName):
                ClipThumbnailView(fileName: fileName, style: .row)
            case .text(let string):
                Text(string.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(HotSlotTypography.rowPrimary)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(item.copiedLine())
                .font(HotSlotTypography.rowSecondary)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
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
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isPinned ? Color.accentColor : .secondary)
                .frame(width: 28, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(isHovering ? 0.12 : 0.07))
                }
        }
        .buttonStyle(.plain)
        .help(isPinned ? "Desfijar" : "Fijar arriba")
        .onHover { isHovering = $0 }
    }
}
