import AppKit
import KeyboardShortcuts
import SwiftUI

/// Ventana del tour. Mismo ciclo de vida que `SettingsWindowController`.
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var appState: AppState?
    private var backdrop: BackdropController?
    private var sessionObservers: [NSObjectProtocol] = []
    /// `true` = el usuario tocó «Empezar» y conviene reabrir el panel al cerrar.
    private var onDismiss: ((Bool) -> Void)?
    private var isAnimating = false
    private var reopenPanelOnDismiss = false
    private var sessionActive = false
    private var chromeHiddenForBackground = false
    /// Posición elegida por el usuario (no recentrar al restaurar).
    private var savedChromeFrame: NSRect?

    func show(appState: AppState, onDismiss: @escaping (Bool) -> Void) {
        self.appState = appState
        self.onDismiss = onDismiss
        reopenPanelOnDismiss = false
        sessionActive = true
        chromeHiddenForBackground = false

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
            appState.onboardingHideChrome = { [weak self] in self?.hideChrome() }
            appState.onboardingRestoreChrome = { [weak self] in self?.restoreChrome() }
        }

        registerSessionObservers()

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

    /// Oculta tour y fondo sin terminar la sesión (otra app o aviso del sistema).
    func hideChrome() {
        guard sessionActive, let window else { return }
        guard window.isVisible else {
            chromeHiddenForBackground = true
            MainActor.assumeIsolated { backdrop?.hide() }
            return
        }
        savedChromeFrame = window.frame
        window.orderOut(nil)
        MainActor.assumeIsolated { backdrop?.hide() }
        chromeHiddenForBackground = true
    }

    /// Vuelve a mostrar el tour si la sesión sigue abierta.
    func restoreChrome() {
        guard sessionActive, !isAnimating else { return }
        guard let window else { return }
        guard AppSettings.load().hasCompletedOnboarding == false else { return }
        guard chromeHiddenForBackground || !window.isVisible else { return }
        chromeHiddenForBackground = false
        presentChrome(animated: true, recenter: false)
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

    private func registerSessionObservers() {
        removeSessionObservers()
        let center = NotificationCenter.default
        sessionObservers.append(
            center.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: NSApp,
                queue: .main
            ) { [weak self] _ in
                self?.hideChrome()
            }
        )
        sessionObservers.append(
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: NSApp,
                queue: .main
            ) { [weak self] _ in
                self?.restoreChrome()
            }
        )
    }

    private func removeSessionObservers() {
        for observer in sessionObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        sessionObservers.removeAll()
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
        chromeHiddenForBackground = false
        removeSessionObservers()
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
            appState?.onboardingHideChrome = nil
            appState?.onboardingRestoreChrome = nil
            let reopen = onDismiss
            let openPanel = reopenPanelOnDismiss
            onDismiss = nil
            reopenPanelOnDismiss = false
            reopen?(openPanel)
        }
    }
}
