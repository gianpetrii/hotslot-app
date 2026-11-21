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

    var isVisible: Bool { window?.isVisible == true }

    @MainActor
    func show(appState: AppState, isFirstRun: Bool, onClose: @escaping () -> Void = {}) {
        guard window == nil, appState.account.isConfigured else { onClose(); return }
        self.onClose = onClose
        guard let screen = WindowPlacement.screenForMouse() ?? NSScreen.main else { onClose(); return }

        let model = AccountFlowModel(account: appState.account, isFirstRun: isFirstRun)
        model.onFinish = { [weak self] in self?.dismiss() }
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
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            accountWindow.animator().alphaValue = 1
        }
    }

    @MainActor
    fileprivate func escape() {
        model?.back()
    }

    private func dismiss() {
        guard let window else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            window.contentViewController = nil
            self?.window = nil
            self?.model = nil
            let done = self?.onClose
            self?.onClose = nil
            done?()
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
            AccountCardView(model: model)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .light)
    }
}
