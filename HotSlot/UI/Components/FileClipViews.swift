import AppKit
import QuickLookThumbnailing
import SwiftUI

/// Ícono del archivo al instante y, cuando llega, su miniatura real (PDF, imágenes, etc.).
struct FileClipIconView: View {
    let content: ClipContent
    var side: CGFloat

    @State private var thumbnail: NSImage?

    var body: some View {
        let url = content.resolvedFileURL
        Group {
            if let url {
                Image(nsImage: thumbnail ?? NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .task(id: url.path) { await loadThumbnail(for: url) }
            } else if content.isRemoteOnlyFile {
                Image(systemName: "icloud")
                    .font(.system(size: side * 0.6, weight: .regular))
                    .foregroundStyle(SlotsColor.textoSecundario)
            } else {
                Image(systemName: "questionmark.folder")
                    .font(.system(size: side * 0.6, weight: .regular))
                    .foregroundStyle(SlotsColor.textoSecundario)
            }
        }
        .frame(width: side, height: side)
    }

    @MainActor
    private func loadThumbnail(for url: URL) async {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: side, height: side),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )
        if let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            thumbnail = representation.nsImage
        }
    }
}

/// Bloque de un archivo en un slot: ícono, nombre (se corta por el medio y conserva la extensión) y detalle.
struct SlotFileBlock: View {
    let content: ClipContent
    var iconSize: CGFloat = 48
    var ink: Color = SlotsColor.tinta
    var secondaryInk: Color = SlotsColor.textoSecundario
    var nameLines: Int = 1
    var nameFont: Font = SlotsFont.textoUI

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FileClipIconView(content: content, side: iconSize)
            Text(content.fileName)
                .font(nameFont)
                .foregroundStyle(ink)
                .lineLimit(nameLines)
                .truncationMode(.middle)
                .multilineTextAlignment(.leading)
            Text(content.fileDetail)
                .font(SlotsFont.etiqueta)
                .foregroundStyle(secondaryInk)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
