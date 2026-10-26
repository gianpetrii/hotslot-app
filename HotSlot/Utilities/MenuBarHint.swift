import AppKit

/// Aviso único: macOS puede ocultar iconos de la barra si no hay espacio (no hay API para forzarlo).
enum MenuBarHint {
    @MainActor
    static func presentIfNeeded() {
        var settings = AppSettings.load()
        guard !settings.hasSeenMenuBarHint else { return }
        settings.hasSeenMenuBarHint = true
        settings.save()

        let alert = NSAlert()
        alert.messageText = "\(BrandDisplay.name) está en la barra de menú"
        alert.informativeText = """
        Buscá el ⌘ arriba a la derecha, junto al reloj y el Wi‑Fi.

        Si no lo ves, la barra está llena: macOS oculta iconos hasta que liberás espacio. Podés mover Wi‑Fi, Bluetooth, batería, etc. a solo Centro de control (Ajustes del Sistema → Centro de control), o mantener ⌘ y arrastrar iconos en la barra para reordenarlos.

        Siempre podés abrir el panel con el atajo por defecto ⌘⇧V o volviendo a abrir Slots desde Aplicaciones.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Entendido")
        alert.runModal()
    }
}
