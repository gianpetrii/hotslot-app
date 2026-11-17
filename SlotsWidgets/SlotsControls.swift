import AppIntents
import SwiftUI
import WidgetKit

/// Control «Abrir Slots» para el Centro de Control, la pantalla de bloqueo y el Botón de Acción.
struct OpenSlotsControl: ControlWidget {
    static let kind = "com.hotslot.app.ios.control.open"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenSlotsIntent()) {
                Label("Abrir Slots", systemImage: "square.grid.2x2")
            }
        }
        .displayName("Abrir Slots")
        .description("Abre Slots desde el Centro de Control o la pantalla de bloqueo.")
    }
}

/// Qué slot copia el control.
struct CopySlotControlConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Slot a copiar"

    @Parameter(title: "Slot")
    var slot: SlotAppEntity?

    init() {}
}

/// Control «Copiar slot»: un toque copia el slot elegido, sin abrir la app.
struct CopySlotControl: ControlWidget {
    static let kind = "com.hotslot.app.ios.control.copy"

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: CopySlotControlConfiguration) -> SlotAppEntity? {
            configuration.slot
        }

        func currentValue(configuration: CopySlotControlConfiguration) async throws -> SlotAppEntity? {
            configuration.slot
        }
    }

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: Self.kind, provider: Provider()) { slot in
            ControlWidgetButton(action: CopySlotIntent(slot: slot ?? .missing)) {
                Label(slot?.title ?? "Elegir slot", systemImage: "doc.on.doc")
            }
        }
        .displayName("Copiar slot")
        .description("Copia un slot al portapapeles con un toque.")
        .promptsForUserConfiguration()
    }
}
