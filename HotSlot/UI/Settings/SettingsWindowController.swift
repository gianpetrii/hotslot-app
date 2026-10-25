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
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "Ajustes de \(BrandDisplay.name)"
            settingsWindow.isReleasedWhenClosed = false
            settingsWindow.delegate = self
            // Por encima del panel flotante (`floating + 1` en `PanelController`).
            settingsWindow.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
            settingsWindow.collectionBehavior = [.moveToActiveSpace]
            settingsWindow.animationBehavior = .none
            window = settingsWindow
        }

        KeyboardShortcuts.disable(KeyboardShortcuts.Name.allShortcutNames)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        guard let window else { return }
        installContent(in: window)

        if window.isVisible {
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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

    /// El TabView/Recorder de Ajustes usa ViewBridge. Achicar o `close()` tira una excepción
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
            let hosting = NSHostingController(rootView: SettingsView(appState: appState))
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
            let reopen = onDismiss
            onDismiss = nil
            reopen?()
        }
    }
}
