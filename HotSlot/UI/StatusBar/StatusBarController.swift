import AppKit
import SwiftUI

/// Icono en menu bar con menú contextual.
@MainActor
final class StatusBarController {
    /// Nuevo nombre: si el usuario ocultó el ítem con ⌘+arrastrar, macOS no lo restaura con el mismo `autosaveName`.
    private static let statusItemAutosaveName = "com.slots.app.menuBarStatus.v2"

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
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        configureButton()
    }

    /// Llamar al volver a `.accessory` (Ajustes/onboarding) por si el sistema ocultó el ítem.
    func refreshVisibility() {
        statusItem.isVisible = true
        configureButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        statusItem.autosaveName = Self.statusItemAutosaveName
        statusItem.isVisible = true
        button.imagePosition = .imageOnly
        button.title = ""
        button.appearsDisabled = false

        if let image = Self.menuBarImage() {
            button.image = image
        } else {
            button.title = "S"
            button.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        }

        button.toolTip = "\(BrandDisplay.name) — atajo para abrir el panel (editable en Ajustes)"
        button.action = #selector(statusBarClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private static func menuBarImage() -> NSImage? {
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        if let asset = NSImage(named: "MenuBarIcon"),
           let image = asset.copy() as? NSImage {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        if let symbol = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: BrandDisplay.name)?
            .withSymbolConfiguration(symbolConfig) {
            let template = (symbol.copy() as? NSImage) ?? symbol
            template.isTemplate = true
            return template
        }
        return nil
    }

    private func buildContextMenu(includeDeveloperItems: Bool) -> NSMenu {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Ver todo", action: #selector(togglePanel), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let libraryItem = NSMenuItem(title: "Biblioteca", action: nil, keyEquivalent: "")
        let libraryMenu = NSMenu()
        let libraries = appState.libraryWorkspace.workspace.libraries.sorted { $0.order < $1.order }
        let activeId = appState.libraryWorkspace.workspace.activeLibraryId
        for library in libraries {
            let item = NSMenuItem(
                title: library.id == activeId ? "✓ \(library.name)" : library.name,
                action: #selector(selectLibrary(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = library.id
            libraryMenu.addItem(item)
        }
        libraryItem.submenu = libraryMenu
        menu.addItem(libraryItem)

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

    @objc private func selectLibrary(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        appState.switchLibrary(to: id)
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
