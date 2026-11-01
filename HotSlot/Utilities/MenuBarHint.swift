import AppKit

/// Aviso único: macOS puede ocultar iconos de la barra si no hay espacio (no hay API para forzarlo).
enum MenuBarHint {
    @MainActor
    static func presentIfNeeded() {
        var settings = AppSettings.load()
        guard !settings.hasSeenMenuBarHint else { return }
        settings.hasSeenMenuBarHint = true
        settings.save()

        MenuBarGuide.present()
    }
}
