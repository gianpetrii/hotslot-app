import AppKit
import SwiftUI

enum ClipThumbnailStyle {
    case row
    case slot
}

/// Miniatura solo para imágenes.
struct ClipThumbnailView: View {
    let fileName: String
    var style: ClipThumbnailStyle = .row

    var body: some View {
        Group {
            if let image = PasteboardHelper.loadImage(named: fileName) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.primary.opacity(0.05)
                    Image(systemName: "photo")
                        .font(.system(size: style == .row ? 16 : 20, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: style == .row ? HotSlotDesign.thumbnailSize : nil,
               height: style == .row ? HotSlotDesign.thumbnailSize : nil)
        .frame(maxWidth: style == .slot ? .infinity : nil,
               maxHeight: style == .slot ? .infinity : nil)
        .clipShape(RoundedRectangle(cornerRadius: HotSlotDesign.thumbnailCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HotSlotDesign.thumbnailCornerRadius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5)
        }
    }
}

/// Ícono de documento para clips de texto (sin renderizar el texto como imagen).
struct TextClipIcon: View {
    var size: CGFloat = HotSlotDesign.thumbnailSize

    var body: some View {
        Image(systemName: "doc.text")
            .font(.system(size: size * 0.4, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: HotSlotDesign.thumbnailCornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: HotSlotDesign.thumbnailCornerRadius, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                    }
            }
    }
}
