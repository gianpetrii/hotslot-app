import SwiftUI

struct ClipRowView: View {
    let item: ClipItem
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                        }
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.content.previewText)
                    .lineLimit(2)
                    .font(HotSlotTypography.rowPrimary)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if let app = item.sourceAppName {
                        Text(app)
                            .font(HotSlotTypography.rowSecondary)
                            .foregroundStyle(.tertiary)
                    }
                    Text(item.createdAt, style: .relative)
                        .font(HotSlotTypography.rowSecondary)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: HotSlotDesign.rowCornerRadius, style: .continuous)
                .fill(backgroundFill)
                .overlay {
                    RoundedRectangle(cornerRadius: HotSlotDesign.rowCornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: isSelected ? 1 : 0.5)
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: HotSlotDesign.rowCornerRadius, style: .continuous))
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    private var backgroundFill: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor.opacity(0.2))
        }
        if isHovering {
            return AnyShapeStyle(Color.primary.opacity(0.07))
        }
        return AnyShapeStyle(Color.clear)
    }

    private var borderColor: Color {
        if isSelected { return Color.accentColor.opacity(0.4) }
        if isHovering { return Color.white.opacity(0.14) }
        return Color.clear
    }

    private var iconName: String {
        switch item.content {
        case .text: return "doc.text"
        case .image: return "photo"
        }
    }
}
