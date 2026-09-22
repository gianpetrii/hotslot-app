import SwiftUI

@main
struct HotSlotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            if let state = appDelegate.appState {
                SettingsView(appState: state)
            } else {
                Text("Cargando…")
            }
        }
    }
}
