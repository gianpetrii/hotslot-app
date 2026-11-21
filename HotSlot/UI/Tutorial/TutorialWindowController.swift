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
    private weak var appStateRef: AppState?

    var isVisible: Bool { window?.isVisible == true }

    /// `onClose` se llama cuando el tutorial termina (por cualquier camino) y ya se quitó de pantalla.
    @MainActor
    func show(appState: AppState, onClose: @escaping () -> Void) {
        guard window == nil else { return }
        self.onClose = onClose
        appStateRef = appState

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
        // El aviso de Accesibilidad del sistema se muestra por delante de esta ventana.
        appState.accessibilityPresentingWindow = tutorialWindow
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
                switch model.phase {
                case .closing, .privacy: model.close()
                case .permission:
                    if model.permissionGranted { model.close() } else { model.requestPermission?() }
                default: model.next()
                }
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
        MainActor.assumeIsolated { appStateRef?.accessibilityPresentingWindow = nil }

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
