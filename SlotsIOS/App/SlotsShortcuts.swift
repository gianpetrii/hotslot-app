import AppIntents

/// Lo que aparece en Atajos, Spotlight y Siri sin configurar nada.
/// Desde Atajos se asignan a Back Tap (Accesibilidad › Tocar atrás) y al Botón de Acción.
struct SlotsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenSlotsIntent(),
            phrases: ["Abrir \(.applicationName)", "Abrí \(.applicationName)"],
            shortTitle: "Abrir Slots",
            systemImageName: "square.grid.2x2"
        )
        AppShortcut(
            intent: CopySlotIntent(),
            phrases: [
                "Copiar un slot de \(.applicationName)",
                "Copiar \(\.$slot) de \(.applicationName)",
            ],
            shortTitle: "Copiar slot",
            systemImageName: "doc.on.doc"
        )
    }
}
