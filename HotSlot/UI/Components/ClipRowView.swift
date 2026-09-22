import SwiftUI

struct ClipRowView: View {
    let item: ClipItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.content.previewText)
                    .lineLimit(2)
                    .font(.body)

                HStack(spacing: 6) {
                    if let app = item.sourceAppName {
                        Text(app)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text(item.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    private var iconName: String {
        switch item.content {
        case .text: return "doc.text"
        case .image: return "photo"
        }
    }
}
