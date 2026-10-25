import SwiftUI

@main
struct HotSlotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Escena vacía: Ajustes solo vía `SettingsWindowController` (evita ventana duplicada de SwiftUI).
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Ajustes…") {
                    appDelegate.openSettingsFromAppMenu()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
