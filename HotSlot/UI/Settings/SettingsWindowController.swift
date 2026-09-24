import AppKit
import KeyboardShortcuts
import SwiftUI

/// Ventana de ajustes (NSWindow regular para que el grabador de atajos reciba teclas).
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    @MainActor
    func show(appState: AppState) {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(appState: appState))
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
            settingsWindow.center()
            window = settingsWindow
        }

        KeyboardShortcuts.disable(KeyboardShortcuts.Name.allShortcutNames)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    func windowWillClose(_ notification: Notification) {
        KeyboardShortcuts.enable(KeyboardShortcuts.Name.allShortcutNames)
    }
}
