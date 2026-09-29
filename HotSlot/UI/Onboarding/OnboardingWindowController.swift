import AppKit
import KeyboardShortcuts
import SwiftUI

/// Ventana del tour. Mismo ciclo de vida que `SettingsWindowController`.
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var appState: AppState?
    /// `true` = el usuario tocó «Empezar» y conviene reabrir el panel al cerrar.
    private var onDismiss: ((Bool) -> Void)?
    private var isAnimating = false
    private var reopenPanelOnDismiss = false

    func show(appState: AppState, onDismiss: @escaping (Bool) -> Void) {
        self.appState = appState
        self.onDismiss = onDismiss
        reopenPanelOnDismiss = false

        if window == nil {
            let onboardingWindow = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: HotSlotDesign.onboardingWidth,
                    height: HotSlotDesign.onboardingHeight
                ),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            onboardingWindow.title = "Cómo usar HotSlot"
            onboardingWindow.isReleasedWhenClosed = false
            onboardingWindow.delegate = self
            onboardingWindow.level = .floating
            onboardingWindow.collectionBehavior = [.moveToActiveSpace]
            onboardingWindow.animationBehavior = .none
            window = onboardingWindow
        }

        KeyboardShortcuts.disable(KeyboardShortcuts.Name.allShortcutNames)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        guard let window else { return }
        installContent(in: window)

        if window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        window.center()
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)

        isAnimating = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = false
            window.animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
        })
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !isAnimating else { return false }
        reopenPanelOnDismiss = false
        beginDismiss(sender)
        return false
    }

    private func requestDismiss(reopenPanel: Bool) {
        guard let window, window.isVisible, !isAnimating else { return }
        reopenPanelOnDismiss = reopenPanel
        beginDismiss(window)
    }

    private func beginDismiss(_ sender: NSWindow) {
        isAnimating = true
        teardownContent(in: sender)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = false
            sender.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.finishDismiss(sender)
        })
    }

    private func installContent(in window: NSWindow) {
        guard window.contentViewController == nil, let appState else { return }
        let hosting = NSHostingController(
            rootView: OnboardingView(
                onFinished: { [weak self] in
                    self?.requestDismiss(reopenPanel: true)
                },
                onCancel: { [weak self] in
                    self?.requestDismiss(reopenPanel: false)
                }
            )
            .environment(appState)
        )
        hosting.safeAreaRegions = []
        window.contentViewController = hosting
    }

    private func teardownContent(in window: NSWindow) {
        window.makeFirstResponder(nil)
        window.contentViewController = nil
    }

    private func finishDismiss(_ sender: NSWindow) {
        sender.orderOut(nil)
        sender.alphaValue = 1
        isAnimating = false

        MainActor.assumeIsolated {
            var settings = AppSettings.load()
            settings.hasCompletedOnboarding = true
            settings.save()

            appState?.hotkeyManager.applyStoredShortcuts()
            let reopen = onDismiss
            let openPanel = reopenPanelOnDismiss
            onDismiss = nil
            reopenPanelOnDismiss = false
            reopen?(openPanel)
        }
    }
}
