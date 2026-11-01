import AppKit

/// macOS no permite «fijar» un icono de la barra por API; solo guía al usuario.
enum MenuBarGuide {
    static let body = """
    Buscá el ⌘ arriba a la derecha, junto al reloj y el Wi‑Fi.

    Para que no se oculte cuando la barra está llena:
    • Mantené ⌘ (Command) y arrastrá \(BrandDisplay.name) hacia la derecha, cerca del reloj: ahí macOS suele dejarlo fijo y no lo reemplaza por otros iconos.
    • O mové Wi‑Fi, Bluetooth, batería, etc. a solo Centro de control (Ajustes del Sistema → Centro de control).

    Siempre podés abrir el panel con el atajo (por defecto ⌘⇧V) o abriendo \(BrandDisplay.name) desde Aplicaciones.
    """

    @MainActor
    static func present() {
        let alert = NSAlert()
        alert.messageText = "Mantener \(BrandDisplay.name) en la barra de menú"
        alert.informativeText = body
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Entendido")
        alert.runModal()
    }
}
