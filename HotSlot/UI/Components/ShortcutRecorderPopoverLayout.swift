import KeyboardShortcuts
import SwiftUI

/// Contenedor de popover con tamaño fijo para que el grabador no mueva el panel al borrar o grabar.
struct ShortcutRecorderPopoverLayout<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(width: width, height: height, alignment: .topLeading)
            .padding(14)
    }
}

struct ShortcutRecorderRow: View {
    let title: String
    let name: KeyboardShortcuts.Name

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            KeyboardShortcuts.Recorder(for: name)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
    }
}
