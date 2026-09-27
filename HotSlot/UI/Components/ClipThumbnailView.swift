import AppKit
import SwiftUI

enum ClipThumbnailStyle {
    case row
    case slot
    case peek
}

/// Miniatura solo para imágenes.
struct ClipThumbnailView: View {
    let fileName: String
    var style: ClipThumbnailStyle = .row
    var isExpanded: Bool = false

    var body: some View {
        switch style {
        case .row:
            rowPreview
        case .slot, .peek:
            imageFill
                .frame(width: rowPreviewWidth, height: rowPreviewHeight)
                .frame(
                    maxWidth: style == .slot || style == .peek ? .infinity : nil,
                    maxHeight: style == .slot || style == .peek ? .infinity : nil
                )
                .clipShape(RoundedRectangle(cornerRadius: clipRadius, style: .continuous))
        }
    }

    /// Cerrada: recorte 128×76. Abierta: todo el ancho, proporción original (`.fit`).
    @ViewBuilder
    private var rowPreview: some View {
        let collapsedWidth = HotSlotDesign.imageRowPreviewWidth
        let collapsedHeight = HotSlotDesign.imageRowPreviewHeight

        Group {
            if let nsImage = PasteboardHelper.loadImage(named: fileName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(
                        isExpanded ? (nsImage.size.width / max(nsImage.size.height, 1)) : nil,
                        contentMode: isExpanded ? .fit : .fill
                    )
            } else {
                ZStack {
                    Color.primary.opacity(0.05)
                    Image(systemName: "photo")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(
            width: isExpanded ? nil : collapsedWidth,
            height: isExpanded ? nil : collapsedHeight,
            alignment: .topLeading
        )
        .frame(
            maxWidth: isExpanded ? .infinity : collapsedWidth,
            maxHeight: isExpanded ? HotSlotDesign.imageRowPreviewMaxExpandedHeight : collapsedHeight,
            alignment: .topLeading
        )
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: clipRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: clipRadius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var imageFill: some View {
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

    private var clipRadius: CGFloat {
        switch style {
        case .slot: return HotSlotDesign.cardCornerRadius
        case .peek: return 8
        case .row: return HotSlotDesign.thumbnailCornerRadius
        }
    }

    private var rowPreviewWidth: CGFloat? {
        switch style {
        case .row: return HotSlotDesign.imageRowPreviewWidth
        case .peek: return HotSlotDesign.slotPeekWidth
        case .slot: return nil
        }
    }

    private var rowPreviewHeight: CGFloat? {
        switch style {
        case .row: return HotSlotDesign.imageRowPreviewHeight
        case .peek: return HotSlotDesign.slotPeekImageHeight
        case .slot: return nil
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
