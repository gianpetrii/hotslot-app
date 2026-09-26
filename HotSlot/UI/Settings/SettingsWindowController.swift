import AppKit
import KeyboardShortcuts
import SwiftUI

/// Ventana de ajustes regular. Las apps de menú bar no reciben teclas hasta pasar a `.regular`.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var appState: AppState?

    @MainActor
    func show(appState: AppState) {
        self.appState = appState
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(appState: appState))
            hosting.safeAreaRegions = []
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "Ajustes de HotSlot"
            settingsWindow.contentViewController = hosting
            settingsWindow.isReleasedWhenClosed = false
            settingsWindow.delegate = self
            settingsWindow.level = .floating
            settingsWindow.collectionBehavior = [.moveToActiveSpace]
            settingsWindow.center()
            window = settingsWindow
        }

        KeyboardShortcuts.disable(KeyboardShortcuts.Name.allShortcutNames)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(window?.contentView)
    }

    @MainActor
    func windowWillClose(_ notification: Notification) {
        appState?.hotkeyManager.applyStoredShortcuts()
        appState?.noteShortcutsChanged()
        NSApp.setActivationPolicy(.accessory)
    }
}
