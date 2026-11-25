import SwiftUI

/// Raíz de la app: la pantalla de slots y, encima, la carga animada al abrir en frío.
struct RootView: View {
    @State private var isLoading = true
    @State private var isLeaving = false
    /// La bienvenida se ve una sola vez; después se puede repetir desde Ajustes.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            SlotsScreen()
            if !hasCompletedOnboarding && !isLoading {
                OnboardingView { withAnimation(.easeOut(duration: 0.25)) { hasCompletedOnboarding = true } }
                    .transition(.opacity)
                    .zIndex(2)
            }
            if isLoading {
                LoadingView(isLeaving: isLeaving)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            // Mínimo 800 ms en pantalla, aunque los datos ya estén.
            try? await Task.sleep(for: .milliseconds(800))
            withAnimation(.easeOut(duration: 0.3)) { isLeaving = true }
            withAnimation(.easeOut(duration: 0.3).delay(0.1)) { isLoading = false }
        }
    }
}
