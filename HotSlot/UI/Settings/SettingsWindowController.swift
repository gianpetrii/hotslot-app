import AppKit
import KeyboardShortcuts
import SwiftUI

/// Ventana de ajustes regular. Las apps de menú bar no reciben teclas hasta pasar a `.regular`.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var appState: AppState?
    private var onDismiss: (() -> Void)?
    private var isAnimating = false
    /// Misma posición para Ajustes, Licencia, etc. mientras el panel siga en esa pantalla.
    private var lockedPlacementFrame: NSRect?

    func show(
        appState: AppState,
        panelAnchorFrame: NSRect? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.appState = appState
        self.onDismiss = onDismiss

        if window == nil {
            let settingsWindow = NSWindow(
                contentRect: NSRect(origin: .zero, size: WindowPlacement.settingsWindowSize),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "Ajustes de \(BrandDisplay.name)"
            settingsWindow.isReleasedWhenClosed = false
            settingsWindow.delegate = self
            settingsWindow.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
            settingsWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            settingsWindow.animationBehavior = .none
            settingsWindow.contentMinSize = WindowPlacement.settingsWindowSize
            settingsWindow.contentMaxSize = WindowPlacement.settingsWindowSize
            window = settingsWindow
        }

        KeyboardShortcuts.disable(KeyboardShortcuts.Name.allShortcutNames)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        guard let window else { return }
        installContent(in: window)
        MainActor.assumeIsolated {
            appState.accessibilityPresentingWindow = window
            appState.isSettingsWindowVisible = true
        }

        let screen = panelAnchorFrame.flatMap { WindowPlacement.screenContaining($0) }
            ?? WindowPlacement.screenForMouse()
            ?? NSScreen.main
        if let screen {
            let frame: NSRect
            if let panelAnchorFrame {
                frame = WindowPlacement.utilityWindowFrame(beside: panelAnchorFrame, on: screen)
                lockedPlacementFrame = frame
            } else if let lockedPlacementFrame {
                frame = lockedPlacementFrame
            } else {
                frame = WindowPlacement.centeredFrame(
                    size: WindowPlacement.settingsWindowSize,
                    on: screen
                )
            }
            applyLockedPlacement(frame, to: window)
        }

        if window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            schedulePlacementReassertion()
            return
        }

        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)

        isAnimating = true
        WindowPlacement.fadeIn(window) { [weak self] in
            self?.isAnimating = false
            self?.schedulePlacementReassertion()
        }
    }

    private func applyLockedPlacement(_ frame: NSRect, to window: NSWindow) {
        window.setFrame(frame, display: true)
    }

    /// El scroll a Licencia puede mover el layout; volvemos a la misma posición que Ajustes.
    private func schedulePlacementReassertion() {
        guard let lockedPlacementFrame, let window else { return }
        let frame = lockedPlacementFrame
        DispatchQueue.main.async { [weak self] in
            self?.applyLockedPlacement(frame, to: window)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.applyLockedPlacement(frame, to: window)
        }
    }

    /// Sin `orderBack`: la ventana sigue visible aunque otra app o el menú bar tomen el foco.
    /// El TabView/Recorder de Ajustes usa ViewBridge; `windowShouldClose` anima el cierre para que Xcode no quede en `(lldb)` con la ventana clavada.
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
            appState?.isSettingsWindowVisible = false
            let reopen = onDismiss
            onDismiss = nil
            reopen?()
        }
    }
}
