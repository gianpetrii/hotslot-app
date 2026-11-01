import KeyboardShortcuts
import SwiftUI

/// Tour con mini-demostraciones interactivas (hover, layout, arrastre).
struct OnboardingView: View {
    var onFinished: () -> Void
    var onCancel: () -> Void

    @Environment(AppState.self) private var appState
    @State private var page = 0
    @State private var accessibilityTrusted = AccessibilityPermission.isTrusted

    private let pages = OnboardingPage.all
    private let pageAnimation = HotSlotDesign.rowExpandAnimation

    var body: some View {
        ZStack {
            VisualEffectBackground(
                material: .hudWindow,
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
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            accessibilityTrusted = AccessibilityPermission.isTrusted
        }
    }

    private var header: some View {
        HStack {
            Button("Saltar") { onCancel() }
                .buttonStyle(.plain)
                .font(SlotsFont.textoUI)
                .foregroundStyle(SlotsColor.textoSecundario)
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
                .font(SlotsFont.tituloCard)
                .foregroundStyle(SlotsColor.tinta)

            Text(item.caption)
                .font(SlotsFont.textoUI)
                .foregroundStyle(SlotsColor.textoSecundario)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            if item.demo == .accessibility {
                AccessibilityGrantSection(isTrusted: $accessibilityTrusted, style: .onboarding)
            } else if item.demo == .shortcutsSummary {
                onboardingShortcutsSummary
            } else if item.demo == .menuBar {
                menuBarBlock
            } else {
                onboardingDemo(for: item.demo)
                    .padding(.horizontal, 4)
            }

            if item.hint != nil, item.demo != .accessibility {
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

    private var onboardingShortcutsSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            shortcutRow("⌘⌃A", "Guardar en slot 1")
            shortcutRow("⌘⇧A", "Pegar slot 1")
            shortcutRow("⌘⇧V", "Ver todos")
            Text("A · S · D · Q · W = slots 1 a 5")
                .font(SlotsFont.etiqueta)
                .foregroundStyle(SlotsColor.textoSecundario)
                .padding(.top, 4)
        }
        .padding(SlotsSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous)
                .fill(SlotsColor.teclaFondo)
        }
        .padding(.top, 8)
    }

    private func shortcutRow(_ keys: String, _ action: String) -> some View {
        HStack {
            Text(keys)
                .font(SlotsFont.etiqueta)
                .foregroundStyle(SlotsColor.tinta)
                .frame(width: 72, alignment: .leading)
            Text(action)
                .font(SlotsFont.textoUI)
                .foregroundStyle(SlotsColor.textoTerciario)
        }
    }

    private var menuBarBlock: some View {
        VStack(spacing: 14) {
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 64, height: 64)
                .background {
                    RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                }

            OnboardingChromeButton(title: "Cómo mantener ⌘ visible", emphasized: true) {
                MenuBarGuide.present()
            }
        }
        .padding(.top, 16)
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
            title: "Tus slots",
            caption: "Guardá links, textos, imágenes o colores en un slot y pegalos con un atajo, sin abrir nada.",
            demo: .shortcutsSummary,
            hint: "Guardar ⌘⌃ A·S·D·Q·W · Pegar ⌘⇧ A·S·D·Q·W · Ver todo ⌘⇧V"
        ),
        OnboardingPage(
            title: "Un permiso y listo",
            caption: "Para pegar en cualquier app sin abrir Slots, macOS te pide habilitar Accesibilidad.",
            demo: .accessibility,
            hint: "Slots solo usa este permiso para pegar lo que elegís en la app que tenés abierta."
        ),
        OnboardingPage(
            title: "Tus atajos",
            caption: "Vienen listos para usar. Podés cambiarlos cuando quieras en Ajustes › Atajos.",
            demo: .shortcutsSummary,
            hint: "¿Algún atajo ya lo usás para otra cosa? Cambialo en Ajustes."
        ),
    ]
}
