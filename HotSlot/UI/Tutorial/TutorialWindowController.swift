import AppKit
import KeyboardShortcuts
import SwiftUI

/// Ventana sin marco que cubre la pantalla y muestra el tutorial de primera vez.
final class TutorialWindowController: NSObject {
    private final class TutorialWindow: NSWindow {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }
    }

    private var window: NSWindow?
    private var model: TutorialModel?
    private var keyMonitor: Any?
    private var onClose: (() -> Void)?

    var isVisible: Bool { window?.isVisible == true }

    /// `onClose` se llama cuando el tutorial termina (por cualquier camino) y ya se quitó de pantalla.
    @MainActor
    func show(appState: AppState, onClose: @escaping () -> Void) {
        guard window == nil else { return }
        self.onClose = onClose

        guard let screen = WindowPlacement.screenForMouse() ?? NSScreen.main else {
            onClose()
            return
        }

        KeyboardShortcuts.disable(KeyboardShortcuts.Name.allShortcutNames)
        NSApp.setActivationPolicy(.regular)

        let model = TutorialModel()
        model.onClose = { [weak self] in self?.dismiss() }
        self.model = model

        let tutorialWindow = TutorialWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        tutorialWindow.isReleasedWhenClosed = false
        tutorialWindow.isOpaque = false
        tutorialWindow.backgroundColor = .clear
        tutorialWindow.hasShadow = false
        tutorialWindow.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 3)
        tutorialWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        tutorialWindow.animationBehavior = .none

        let hosting = NSHostingController(rootView: TutorialView(model: model).environment(appState))
        hosting.safeAreaRegions = []
        tutorialWindow.contentViewController = hosting
        tutorialWindow.setFrame(screen.frame, display: true)

        window = tutorialWindow
        NSApp.activate(ignoringOtherApps: true)
        tutorialWindow.makeKeyAndOrderFront(nil)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    /// Enter y → avanzan, ← vuelve, Esc salta.
    private func handle(_ event: NSEvent) -> NSEvent? {
        guard let model else { return event }
        MainActor.assumeIsolated {
            switch event.keyCode {
            case 36, 76, 124: // return, enter, →
                if model.phase == .closing { model.close() } else { model.next() }
            case 123: // ←
                model.back()
            case 53: // esc
                model.close()
            default:
                break
            }
        }
        // Se come la tecla: nada del tutorial debe llegar a otra ventana.
        return nil
    }

    private func dismiss() {
        guard let window else { return }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        model = nil

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            window.contentViewController = nil
            self?.window = nil
            let done = self?.onClose
            self?.onClose = nil
            done?()
        })
    }
}
