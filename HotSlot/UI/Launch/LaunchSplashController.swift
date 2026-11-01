import AppKit
import SwiftUI

/// Pantalla de arranque Mac 00 (handoff): degradé + slot de vidrio que se estira.
final class LaunchSplashController {
    private var panel: NSPanel?
    private var hosting: NSHostingController<LaunchSplashView>?
    private var completion: (() -> Void)?

    @MainActor
    func show(completion: @escaping () -> Void) {
        self.completion = completion

        guard let screen = NSScreen.main else {
            completion()
            return
        }

        let frame = screen.frame
        let splashPanel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        splashPanel.isOpaque = false
        splashPanel.backgroundColor = .clear
        splashPanel.level = .floating
        splashPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        splashPanel.hasShadow = false
        splashPanel.isFloatingPanel = true

        let view = LaunchSplashView(onFinish: { [weak self] in
            self?.dismiss()
        })
        let host = NSHostingController(rootView: view)
        host.safeAreaRegions = []
        splashPanel.contentViewController = host

        panel = splashPanel
        hosting = host
        splashPanel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func dismiss() {
        guard let panel else {
            completion?()
            completion = nil
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.28
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.panel = nil
            self?.hosting = nil
            let done = self?.completion
            self?.completion = nil
            done?()
        })
    }
}

private struct LaunchSplashView: View {
    let onFinish: () -> Void
    @State private var slotWidth: CGFloat = 88
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SlotsColor.naranja, SlotsColor.oxido, SlotsColor.arena.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(SlotsColor.vidrioTinte)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.ultraThinMaterial)
                        }
                        .frame(width: slotWidth, height: 72)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                        }

                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(SlotsColor.naranja)
                            .frame(width: 28, height: 28)
                        Text(BrandDisplay.name)
                            .font(SlotsFont.tituloCard)
                            .foregroundStyle(SlotsColor.tinta)
                    }
                    .opacity(contentOpacity)
                }

                ProgressView()
                    .controlSize(.small)
                    .tint(.white.opacity(0.8))
                    .opacity(contentOpacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                contentOpacity = 1
            }
            withAnimation(.easeInOut(duration: 2.0)) {
                slotWidth = 320
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.15) {
                onFinish()
            }
        }
    }
}

enum LaunchSplashPolicy {
    /// Arranque visible salvo inicio en segundo plano (p. ej. al iniciar sesión).
    static func shouldPresent(userOpenedApp: Bool, onboardingPending: Bool) -> Bool {
        if onboardingPending { return true }
        if userOpenedApp { return true }
        return false
    }

    static func isBackgroundSessionLaunch(userOpenedApp: Bool) -> Bool {
        !userOpenedApp && NSWorkspace.shared.frontmostApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
    }
}
