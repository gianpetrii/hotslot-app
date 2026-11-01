import AppKit
import SwiftUI

/// Icono en menu bar con menú contextual.
@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let appState: AppState
    private let panelController: PanelController
    private let onCheckForUpdates: () -> Void
    private let developerActions: StatusBarDeveloperActions

    init(
        appState: AppState,
        panelController: PanelController,
        developerActions: StatusBarDeveloperActions,
        onCheckForUpdates: @escaping () -> Void
    ) {
        self.appState = appState
        self.panelController = panelController
        self.developerActions = developerActions
        self.onCheckForUpdates = onCheckForUpdates
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "com.hotslot.app.menuBarIcon"

        configureButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        button.imagePosition = .imageOnly
        button.title = ""
        button.appearsDisabled = false

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let baseSymbol = NSImage(systemSymbolName: "command", accessibilityDescription: BrandDisplay.name)
        if let configured = baseSymbol?.withSymbolConfiguration(symbolConfig) {
            let template = (configured.copy() as? NSImage) ?? configured
            template.isTemplate = true
            button.image = template
        } else if let asset = NSImage(named: "MenuBarIcon"),
                  let image = asset.copy() as? NSImage {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            button.image = image
        } else {
            button.title = "⌘"
            button.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        }
        statusItem.isVisible = true
        button.toolTip = "\(BrandDisplay.name) — atajo para abrir el panel (editable en Ajustes)"
        button.action = #selector(statusBarClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func buildContextMenu(includeDeveloperItems: Bool) -> NSMenu {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Abrir panel", action: #selector(togglePanel), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Ajustes…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let licenseItem = NSMenuItem(title: "Licencia…", action: #selector(openLicense), keyEquivalent: "")
        licenseItem.target = self
        menu.addItem(licenseItem)

        let purchaseItem = NSMenuItem(title: "Comprar licencia…", action: #selector(openPurchase), keyEquivalent: "")
        purchaseItem.target = self
        menu.addItem(purchaseItem)

        let tourItem = NSMenuItem(title: "Cómo usar \(BrandDisplay.name)", action: #selector(openTour), keyEquivalent: "")
        tourItem.target = self
        menu.addItem(tourItem)

        let updatesItem = NSMenuItem(title: "Buscar actualizaciones…", action: #selector(checkForUpdates), keyEquivalent: "")
        updatesItem.target = self
        menu.addItem(updatesItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Salir de \(BrandDisplay.name)", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        if includeDeveloperItems {
            DeveloperMenuBuilder.appendItems(to: menu, target: developerActions)
        }

        return menu
    }

    @objc private func statusBarClicked() {
        guard let event = NSApp.currentEvent else {
            togglePanel()
            return
        }
        if event.type == .rightMouseUp {
            if let button = statusItem.button {
                let optionHeld = event.modifierFlags.contains(.option)
                buildContextMenu(includeDeveloperItems: optionHeld)
                    .popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
            }
        } else {
            togglePanel()
        }
    }

    @objc private func togglePanel() {
        if appState.isSettingsWindowVisible {
            if !panelController.isVisible {
                appState.focusTracker.captureForUpcomingPaste()
                panelController.show()
                appState.isPanelVisible = true
            }
            return
        }
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

    @objc private func openLicense() {
        appState.openLicenseSettings()
    }

    @objc private func openPurchase() {
        appState.openPurchasePage()
    }

    @objc private func openTour() {
        appState.openOnboarding?()
    }

    @objc private func checkForUpdates() {
        onCheckForUpdates()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
