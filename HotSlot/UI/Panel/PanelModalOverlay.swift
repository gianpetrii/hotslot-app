import SwiftUI

/// Modal centrado sobre el panel (`.sheet` no es fiable en `NSPanel`).
struct PanelModalOverlay<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            content()
                .background {
                    RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                        .fill(SlotsColor.papel)
                        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
                }
        }
        .transition(.opacity)
    }
}
