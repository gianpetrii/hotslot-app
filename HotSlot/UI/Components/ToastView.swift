import SwiftUI

/// Toast sutil con material nativo.
struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.callout)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                    }
            }
            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }
}
