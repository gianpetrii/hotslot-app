import AppKit
import SwiftUI

/// Ventana sin marco que cubre la pantalla con el velo del tutorial y la tarjeta de inicio de sesión.
final class AccountWindowController: NSObject {
    private final class AccountWindow: NSWindow {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }

        override func cancelOperation(_ sender: Any?) {
            (delegate as? AccountWindowController)?.escape()
        }
    }

    private var window: NSWindow?
    private var model: AccountFlowModel?
    private var onClose: (() -> Void)?
    private weak var appStateRef: AppState?

    var isVisible: Bool { window?.isVisible == true }

    /// - Parameters:
    ///   - deleteCompletion: si se pasa, muestra la confirmación de contraseña para eliminar la cuenta.
    ///   - onBrowserFlow: avisa cuando Google abre o cierra el navegador (Ajustes deja de flotar mientras tanto).
    @MainActor
    func show(
        appState: AppState,
        isFirstRun: Bool,
        deleteCompletion: ((String?) -> Void)? = nil,
        confirmation: AppConfirmation? = nil,
        onBrowserFlow: @escaping (Bool) -> Void = { _ in },
        onClose: @escaping () -> Void = {}
    ) {
        guard window == nil, appState.account.isConfigured else { onClose(); return }
        self.onClose = onClose
        appStateRef = appState
        guard let screen = WindowPlacement.screenForMouse() ?? NSScreen.main else { onClose(); return }

        let model = AccountFlowModel(account: appState.account, isFirstRun: isFirstRun)
        model.onFinish = { [weak self] in self?.dismiss() }
        if let confirmation {
            model.confirmation = confirmation
            model.screen = .confirm
        }
        if let deleteCompletion {
            model.deleteCompletion = deleteCompletion
            model.screen = .confirmDelete
        }
        self.model = model

        let accountWindow = AccountWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        accountWindow.isReleasedWhenClosed = false
        accountWindow.isOpaque = false
        accountWindow.backgroundColor = .clear
        accountWindow.hasShadow = false
        accountWindow.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 4)
        accountWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        accountWindow.animationBehavior = .none
        accountWindow.delegate = self
        model.presentingWindow = { [weak accountWindow] in accountWindow }
        // Google abre el navegador: esta ventana se vuelve transparente e intocable para que el navegador quede primero,
        // y al volver recupera el frente.
        model.onBrowserFlow = { [weak accountWindow] active in
            guard let accountWindow else { return }
            onBrowserFlow(active)
            accountWindow.ignoresMouseEvents = active
            accountWindow.level = active ? .normal : NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 4)
            accountWindow.alphaValue = active ? 0 : 1
            if !active {
                NSApp.activate(ignoringOtherApps: true)
                accountWindow.makeKeyAndOrderFront(nil)
            }
        }

        let root = AccountWindowContent(model: model)
        let hosting = NSHostingController(rootView: root)
        hosting.safeAreaRegions = []
        accountWindow.contentViewController = hosting
        accountWindow.setFrame(screen.frame, display: true)
        accountWindow.alphaValue = 0
        window = accountWindow

        // Apple y Google abren su propia ventana: Ajustes no debe cerrarse mientras tanto.
        appState.suppressSettingsAutoClose(for: 600)
        appState.accessibilityPresentingWindow = nil
        NSApp.activate(ignoringOtherApps: true)
        accountWindow.makeKeyAndOrderFront(nil)
        WindowPlacement.fadeIn(accountWindow)
    }

    @MainActor
    fileprivate func escape() {
        model?.back()
    }

    private func dismiss() {
        guard let window else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            window.contentViewController = nil
            self?.window = nil
            let pending = self?.model?.afterClose
            self?.model = nil
            // Ajustes vuelve a cerrarse con un clic afuera (la pausa era solo para Apple y Google).
            MainActor.assumeIsolated { self?.appStateRef?.releaseSettingsAutoClose() }
            let done = self?.onClose
            self?.onClose = nil
            done?()
            // La acción confirmada corre con la ventana ya cerrada (puede abrir otra).
            pending?()
        })
    }
}

extension AccountWindowController: NSWindowDelegate {}

private struct AccountWindowContent: View {
    @Bindable var model: AccountFlowModel

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow, cornerRadius: 0)
                .opacity(0.6)
            Color(slotsHex: 0x1C140E, opacity: 0.30)
                .contentShape(Rectangle())
                // Un clic fuera de la tarjeta equivale a «Ahora no» o a la flecha de volver (según la pantalla).
                .onTapGesture { if !model.isBusy { model.back() } }
            AccountCardView(model: model)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .light)
    }
}
