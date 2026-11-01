import AppKit
import KeyboardShortcuts
import SwiftUI

/// Ventana de ajustes regular. Las apps de menú bar no reciben teclas hasta pasar a `.regular`.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var appState: AppState?
    private var onDismiss: (() -> Void)?
    private var isAnimating = false

    func show(appState: AppState, onDismiss: @escaping () -> Void) {
        self.appState = appState
        self.onDismiss = onDismiss

        if window == nil {
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 540),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "Ajustes de \(BrandDisplay.name)"
            settingsWindow.isReleasedWhenClosed = false
            settingsWindow.delegate = self
            settingsWindow.level = .normal
            settingsWindow.collectionBehavior = [.moveToActiveSpace]
            settingsWindow.animationBehavior = .none
            window = settingsWindow
        }

        KeyboardShortcuts.disable(KeyboardShortcuts.Name.allShortcutNames)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        guard let window else { return }
        installContent(in: window)
        MainActor.assumeIsolated {
            appState.accessibilityPresentingWindow = window
        }

        if window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let screen = WindowPlacement.screenForMouse() ?? NSScreen.main
        if let screen {
            window.setFrame(WindowPlacement.centeredFrame(size: window.frame.size, on: screen), display: true)
        }
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)

        isAnimating = true
        WindowPlacement.fadeIn(window) { [weak self] in
            self?.isAnimating = false
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        window?.orderBack(nil)
    }

    /// El TabView/Recorder de Ajustes usa ViewBridge.
    /// y Xcode frena en `(lldb)` con la ventana clavada.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !isAnimating else { return false }
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
        return false
    }

    private func installContent(in window: NSWindow) {
        guard let appState else { return }
        if window.contentViewController == nil {
            let hosting = NSHostingController(
                rootView: SettingsView(appState: appState).environment(appState)
            )
            hosting.safeAreaRegions = []
            window.contentViewController = hosting
        }
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
            appState?.hotkeyManager.applyStoredShortcuts()
            appState?.noteShortcutsChanged()
            appState?.accessibilityPresentingWindow = nil
            let reopen = onDismiss
            onDismiss = nil
            reopen?()
        }
    }
}
