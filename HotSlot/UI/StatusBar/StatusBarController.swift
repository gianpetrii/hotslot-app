import AppKit
import SwiftUI

/// Icono en menu bar con menú contextual.
@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let appState: AppState
    private let panelController: PanelController

    init(appState: AppState, panelController: PanelController) {
        self.appState = appState
        self.panelController = panelController
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        configureButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            button.image = image
            button.image?.size = NSSize(width: 18, height: 18)
        } else if let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "HotSlot") {
            image.isTemplate = true
            button.image = image
        }
        button.toolTip = "HotSlot — ⌘⇧V para abrir el panel"
        button.action = #selector(statusBarClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private lazy var contextMenu: NSMenu = {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Abrir panel", action: #selector(togglePanel), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Ajustes…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let tourItem = NSMenuItem(title: "Cómo usar HotSlot", action: #selector(openTour), keyEquivalent: "")
        tourItem.target = self
        menu.addItem(tourItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Salir de HotSlot", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }()

    @objc private func statusBarClicked() {
        guard let event = NSApp.currentEvent else {
            togglePanel()
            return
        }
        if event.type == .rightMouseUp {
            if let button = statusItem.button {
                contextMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
            }
        } else {
            togglePanel()
        }
    }

    @objc private func togglePanel() {
        if panelController.isVisible {
            panelController.hide()
            appState.isPanelVisible = false
        } else {
            appState.focusTracker.captureForUpcomingPaste()
            panelController.show()
            appState.isPanelVisible = true
        }
    }

    @objc private func openSettings() {
        appState.openSettings?()
    }

    @objc private func openTour() {
        appState.openOnboarding?()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
