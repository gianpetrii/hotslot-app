import AppKit
import KeyboardShortcuts
import SwiftUI

/// Ventana de ajustes regular. Las apps de menú bar no reciben teclas hasta pasar a `.regular`.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    /// Ventana sin marco ni botones (diseño de Dante): se cierra con Esc, ⌘W o clic afuera.
    private final class SettingsWindow: NSWindow {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }

        override func cancelOperation(_ sender: Any?) {
            _ = delegate?.windowShouldClose?(self)
        }

        override func performClose(_ sender: Any?) {
            _ = delegate?.windowShouldClose?(self)
        }
    }

    private var window: NSWindow?

    var isVisible: Bool { window?.isVisible == true }
    private var appState: AppState?
    private var onDismiss: (() -> Void)?
    private var isAnimating = false
    /// Se cerró para dar paso al tutorial: no hay que reabrir el panel detrás.
    private(set) var closedByFocusLoss = false
    private var afterDismiss: (() -> Void)?
    /// Misma posición para Ajustes, Licencia, etc. mientras el panel siga en esa pantalla.
    private var lockedPlacementFrame: NSRect?

    func show(
        appState: AppState,
        panelAnchorFrame: NSRect? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.appState = appState
        self.onDismiss = onDismiss
        closedByFocusLoss = false

        if window == nil {
            let settingsWindow = SettingsWindow(
                contentRect: NSRect(origin: .zero, size: WindowPlacement.settingsWindowSize),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "Ajustes de \(BrandDisplay.name)"
            settingsWindow.isReleasedWhenClosed = false
            settingsWindow.delegate = self
            settingsWindow.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
            settingsWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            settingsWindow.animationBehavior = .none
            // Fondo de vidrio como el del panel: la ventana deja ver el escritorio desenfocado.
            settingsWindow.isOpaque = false
            settingsWindow.backgroundColor = .clear
            settingsWindow.hasShadow = true
            settingsWindow.isMovableByWindowBackground = true
            // Siempre la versión clara, como el resto de la app.
            settingsWindow.appearance = NSAppearance(named: .aqua)
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

        #if DEBUG
        if let dir = UserDefaults.standard.string(forKey: "slotsSettingsSnapDir") {
            snapshotTabs(of: window, into: dir)
        }
        #endif

        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)

        isAnimating = true
        WindowPlacement.fadeIn(window) { [weak self] in
            self?.isAnimating = false
            self?.schedulePlacementReassertion()
        }
    }

    #if DEBUG
    /// Solo para comparar con el diseño sin permiso de grabación de pantalla.
    private func snapshotTabs(of window: NSWindow, into dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        func capture(_ name: String) {
            guard let view = window.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { capture("general.png") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in self?.appState?.pendingSettingsTab = .hotkeys; NotificationCenter.default.post(name: .init("slotsSnapTab"), object: nil) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { capture("atajos.png") }
    }
    #endif

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

    /// Cierra Ajustes sin reabrir el panel y, ya cerrada, ejecuta `then`.
    func dismissForTutorial(then: @escaping () -> Void) {
        guard let window, window.isVisible else { then(); return }
        afterDismiss = then
        closedByFocusLoss = true
        _ = windowShouldClose(window)
    }

    /// Clic afuera o en otra app: se cierra solo, salvo mientras hay una hoja, un aviso del sistema o una página externa.
    func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === self.window else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, let window = self.window, window.isVisible, !self.isAnimating else { return }
            if window.isKeyWindow || window.attachedSheet != nil { return }
            if NSApp.keyWindow?.sheetParent === window { return }
            if let until = self.appState?.settingsAutoCloseSuppressedUntil, until > Date() { return }
            // Igual que Esc: vuelve al panel (otro clic afuera o Esc ahí cierra el panel).
            _ = self.windowShouldClose(window)
        }
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
            let next = afterDismiss
            afterDismiss = nil
            next?()
        }
    }
}
