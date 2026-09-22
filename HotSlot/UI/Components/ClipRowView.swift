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
                .frame(width: 28, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.quaternary.opacity(0.5))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.content.previewText)
                    .lineLimit(2)
                    .font(.callout)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if let app = item.sourceAppName {
                        Label(app, systemImage: "app")
                            .labelStyle(.titleOnly)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text(item.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
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
    }

    private var backgroundFill: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor.opacity(0.18))
        }
        if isHovering {
            return AnyShapeStyle(Color.primary.opacity(0.06))
        }
        return AnyShapeStyle(Color.clear)
    }

    private var borderColor: Color {
        if isSelected { return Color.accentColor.opacity(0.35) }
        if isHovering { return Color.white.opacity(0.12) }
        return Color.clear
    }

    private var iconName: String {
        switch item.content {
        case .text: return "doc.text"
        case .image: return "photo"
        }
    }
}
