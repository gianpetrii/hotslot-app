import AppKit
import KeyboardShortcuts
import SwiftUI

/// Ventana del tour. Mismo ciclo de vida que `SettingsWindowController`.
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var appState: AppState?
    private var backdrop: BackdropController?
    /// `true` = el usuario tocó «Empezar» y conviene reabrir el panel al cerrar.
    private var onDismiss: ((Bool) -> Void)?
    private var isAnimating = false
    private var reopenPanelOnDismiss = false
    private var sessionActive = false
    /// Posición elegida por el usuario (no recentrar al restaurar).
    private var savedChromeFrame: NSRect?

    func show(appState: AppState, onDismiss: @escaping (Bool) -> Void) {
        self.appState = appState
        self.onDismiss = onDismiss
        reopenPanelOnDismiss = false
        sessionActive = true

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
            onboardingWindow.title = "Cómo usar \(BrandDisplay.name)"
            onboardingWindow.isReleasedWhenClosed = false
            onboardingWindow.delegate = self
            onboardingWindow.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
            onboardingWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            onboardingWindow.animationBehavior = .none
            window = onboardingWindow
        }

        MainActor.assumeIsolated {
            appState.accessibilityPresentingWindow = window
        }

        KeyboardShortcuts.disable(KeyboardShortcuts.Name.allShortcutNames)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        guard let window else { return }
        installContent(in: window)
        savedChromeFrame = nil
        presentChrome(animated: window.isVisible == false, recenter: true)
    }

    func windowDidMove(_ notification: Notification) {
        guard let window, window.isVisible, sessionActive else { return }
        savedChromeFrame = window.frame
    }

    private func presentChrome(animated: Bool, recenter: Bool) {
        guard let window else { return }
        guard let screen = WindowPlacement.screenForMouse() ?? NSScreen.main else { return }

        if recenter || savedChromeFrame == nil {
            alignOnScreen(window)
        } else if let savedChromeFrame {
            window.setFrame(savedChromeFrame, display: true)
        }
        MainActor.assumeIsolated {
            if backdrop == nil { backdrop = BackdropController() }
            backdrop?.show(on: screen, passThroughClicks: true)
        }

        guard animated else {
            window.alphaValue = 1
            window.makeKeyAndOrderFront(nil)
            return
        }

        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        isAnimating = true
        WindowPlacement.fadeIn(window) { [weak self] in
            self?.isAnimating = false
        }
    }

    private func alignOnScreen(_ window: NSWindow) {
        guard let screen = WindowPlacement.screenForMouse() ?? NSScreen.main else { return }
        let contentSize = NSSize(
            width: HotSlotDesign.onboardingWidth,
            height: HotSlotDesign.onboardingHeight
        )
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
        let centered = WindowPlacement.centeredFrame(size: frame.size, on: screen)
        frame.origin = centered.origin
        window.setFrame(frame, display: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !isAnimating else { return false }
        reopenPanelOnDismiss = false
        beginDismiss(sender)
        return false
    }

    private func requestDismiss(reopenPanel: Bool) {
        guard let window, !isAnimating else { return }
        guard window.isVisible else { return }
        reopenPanelOnDismiss = reopenPanel
        beginDismiss(window)
    }

    private func beginDismiss(_ sender: NSWindow) {
        isAnimating = true
        sessionActive = false
        teardownContent(in: sender)
        MainActor.assumeIsolated { backdrop?.hide() }

        WindowPlacement.fadeOut(sender) { [weak self] in
            self?.finishDismiss(sender)
        }
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
            settings.hasSeenMenuBarHint = true
            settings.save()

            appState?.hotkeyManager.applyStoredShortcuts()
            appState?.accessibilityPresentingWindow = nil
            let reopen = onDismiss
            let openPanel = reopenPanelOnDismiss
            onDismiss = nil
            if openPanel {
                appState?.presentNotch(.ready)
            }
            reopenPanelOnDismiss = false
            reopen?(openPanel)
        }
    }
}
