import SwiftUI

/// Mismo flujo en onboarding y Ajustes → Permisos: diálogo del sistema primero, Ajustes como respaldo.
struct AccessibilityGrantSection: View {
    enum Style {
        case settingsForm
        case onboarding
    }

    @Environment(AppState.self) private var appState
    @Binding var isTrusted: Bool
    var style: Style = .settingsForm

    var body: some View {
        switch style {
        case .settingsForm:
            settingsBody
        case .onboarding:
            onboardingBody
        }
    }

    private var settingsBody: some View {
        Group {
            if isTrusted {
                Button("Administrar en Ajustes del Sistema") {
                    AccessibilityPermission.openSettings()
                }
            } else {
                Button("Permitir Accesibilidad (diálogo del sistema)") {
                    requestAccessibilityFromUI()
                }
                Button("Abrir panel de Accesibilidad en Ajustes…") {
                    AccessibilityPermission.openSettings()
                }
                Text(AccessibilityPermissionCopy.promptFirst)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var onboardingBody: some View {
        VStack(spacing: 14) {
            if isTrusted {
                Label("Accesibilidad concedida", systemImage: "checkmark.circle.fill")
                    .font(HotSlotTypography.rowSecondary)
                    .foregroundStyle(.secondary)
            } else {
                OnboardingAccessibilityButton(title: "Permitir control de la Mac…", emphasized: true) {
                    requestAccessibilityFromUI()
                }
                OnboardingAccessibilityButton(title: "Abrir Accesibilidad en Ajustes…", emphasized: false) {
                    AccessibilityPermission.openSettings()
                }
                Text(AccessibilityPermissionCopy.promptFirst)
                    .font(HotSlotTypography.rowSecondary)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
        }
        .padding(.top, 8)
    }

    private func requestAccessibilityFromUI() {
        AccessibilityPermission.requestAccessForPaste()
        isTrusted = AccessibilityPermission.isTrusted
        guard !isTrusted else { return }
        appState.showToast("Si no aparece el aviso, abrí Accesibilidad en Ajustes y activá Slots (o agregá la app con +).")
    }
}

enum AccessibilityPermissionCopy {
    static let promptFirst = """
    Tocá «Permitir control de la Mac». macOS muestra un aviso del sistema (una vez por app): elegí abrir Ajustes y activá el interruptor junto a \(BrandDisplay.name). La app no puede hacerlo sola.
    """
}

private struct OnboardingAccessibilityButton: View {
    let title: String
    var emphasized: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(emphasized ? Color.primary : Color.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(emphasized ? (isHovering ? 0.14 : 0.1) : (isHovering ? 0.1 : 0.06)))
                        .overlay {
                            RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                        }
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}
