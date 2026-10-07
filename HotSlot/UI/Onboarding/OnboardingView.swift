import KeyboardShortcuts
import SwiftUI

/// Tour con mini-demostraciones interactivas (hover, layout, arrastre).
struct OnboardingView: View {
    var onFinished: () -> Void
    var onCancel: () -> Void

    @Environment(AppState.self) private var appState
    @State private var page = 0
    private let pages = OnboardingPage.all
    private let pageAnimation = HotSlotDesign.rowExpandAnimation

    var body: some View {
        ZStack {
            VisualEffectBackground(
                material: .menu,
                blendingMode: .behindWindow,
                cornerRadius: HotSlotDesign.cornerRadius
            )

            VStack(spacing: 0) {
                header
                pageContent(pages[page])
                    .id(page)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
                footer
            }
        }
        .frame(width: HotSlotDesign.onboardingWidth, height: HotSlotDesign.onboardingHeight)
        .clipShape(RoundedRectangle(cornerRadius: HotSlotDesign.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HotSlotDesign.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
        }
    }

    private var header: some View {
        HStack {
            Button("Saltar") { onCancel() }
                .buttonStyle(.plain)
                .font(HotSlotTypography.rowSecondary)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(index == page ? Color.primary.opacity(0.45) : Color.primary.opacity(0.12))
                        .frame(width: index == page ? 14 : 6, height: 6)
                        .animation(pageAnimation, value: page)
                }
            }

            HStack(spacing: 8) {
                if page > 0 {
                    OnboardingChromeButton(title: "Atrás", emphasized: false) {
                        go(to: page - 1)
                    }
                }
                Spacer()
                if page < pages.count - 1 {
                    OnboardingChromeButton(title: "Siguiente", emphasized: true) {
                        go(to: page + 1)
                    }
                } else {
                    OnboardingChromeButton(title: "Empezar", emphasized: true) {
                        onFinished()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func pageContent(_ item: OnboardingPage) -> some View {
        VStack(spacing: 12) {
            Text(item.title)
                .font(HotSlotTypography.searchField.weight(.semibold))
                .foregroundStyle(.primary)

            Text(item.caption)
                .font(HotSlotTypography.rowSecondary)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            if item.demo != .automation {
                onboardingDemo(for: item.demo)
                    .padding(.horizontal, 4)
            } else {
                automationBlock
            }

            if item.hint != nil {
                Text(item.hint!)
                    .font(HotSlotTypography.rowSecondary)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var automationBlock: some View {
        VStack(spacing: 14) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 64, height: 64)
                .background {
                    RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                }

            Text("La primera vez que pegues, macOS puede pedir permiso de Automatización para HotSlot en la app destino.")
                .font(HotSlotTypography.rowSecondary)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            OnboardingChromeButton(title: "Ver Automatización en Ajustes…", emphasized: false) {
                AutomationPermission.openSettings()
            }
        }
        .padding(.top, 24)
    }

    private func go(to index: Int) {
        withAnimation(pageAnimation) {
            page = index
        }
    }
}

private struct OnboardingChromeButton: View {
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

private struct OnboardingPage {
    let title: String
    let caption: String
    let demo: OnboardingDemoKind
    var hint: String?

    static let all: [OnboardingPage] = [
        OnboardingPage(
            title: "El panel",
            caption: "Clic en el ícono de la barra o el atajo del buscador.",
            demo: .panel,
            hint: "Slots a la izquierda · historial a la derecha"
        ),
        OnboardingPage(
            title: "Cinco slots",
            caption: "Pasá el mouse sobre el slot — el popover es igual al panel.",
            demo: .slot,
            hint: "Clickear o usar el atajo indicado pega | X en el hover vacía el slot | comando del atajo editable en Ajustes → Atajos"
        ),
        OnboardingPage(
            title: "Historial",
            caption: "Pasá el mouse en las filas — texto e imagen se expanden igual que en el panel.",
            demo: .history,
            hint: "Clic pega · pin fija arriba · buscador filtra"
        ),
        OnboardingPage(
            title: "Arrastrar",
            caption: "Mantené apretado y arrastrá, como en el panel real.",
            demo: .drag
        ),
        OnboardingPage(
            title: "Pegado automático",
            caption: "Un clic pega en la app activa vía Automatización (System Events).",
            demo: .automation,
            hint: "Si macOS lo pide, permití que HotSlot controle la app destino"
        ),
    ]
}
