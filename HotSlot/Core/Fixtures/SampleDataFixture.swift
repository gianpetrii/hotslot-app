import Foundation

/// Datos de ejemplo alineados al panel de diseño (`05-flujos/macos/05-Panel.png`).
enum SampleDataFixture {
    @MainActor
    static func loadExample(
        workspaceStore: LibraryWorkspaceStore,
        slotStore: SlotStore,
        historyStore: HistoryStore
    ) {
        let now = Date()
        let libraries = Library.defaults(now: now)
        let trabajo = libraries[0].id
        let personal = libraries[1].id
        let clientes = libraries[2].id

        func makeSlot(
            libraryId: UUID,
            order: Int,
            title: String,
            kind: SlotKind,
            text: String? = nil,
            meta: String? = nil
        ) -> SlotRecord {
            SlotRecord(
                id: UUID(),
                libraryId: libraryId,
                order: order,
                title: title,
                kind: kind,
                textPayload: text,
                imageFileName: nil,
                linkURL: kind == .link ? text : nil,
                meta: meta,
                createdAt: now,
                updatedAt: now
            )
        }

        let presupuesto = """
        Hola, gracias por escribir. Te paso el presupuesto actualizado con plazos y entregables. \
        Cualquier duda avisame y lo vemos en una call breve esta semana.
        """

        var slots: [SlotRecord] = [
            makeSlot(
                libraryId: trabajo,
                order: 1,
                title: "Mi portfolio",
                kind: .link,
                text: "https://behance.net/gallery/ejemplo",
                meta: "Link · behance.net"
            ),
            makeSlot(
                libraryId: trabajo,
                order: 2,
                title: "Link de la reunión",
                kind: .link,
                text: "https://meet.google.com/abc-defg-hij",
                meta: "Link · meet.google.com"
            ),
            makeSlot(
                libraryId: trabajo,
                order: 3,
                title: "Respuesta presupuesto",
                kind: .text,
                text: presupuesto,
                meta: "Texto · 36 palabras"
            ),
            makeSlot(
                libraryId: trabajo,
                order: 4,
                title: "#E2501D",
                kind: .color,
                text: "#E2501D",
                meta: "Color"
            ),
            makeSlot(libraryId: trabajo, order: 5, title: "Slot 5", kind: .text),
            makeSlot(
                libraryId: personal,
                order: 1,
                title: "Dirección estudio",
                kind: .text,
                text: "Av. Corrientes 1234, CABA",
                meta: "Texto · 6 palabras"
            ),
            makeSlot(libraryId: personal, order: 2, title: "Slot 2", kind: .text),
            makeSlot(libraryId: personal, order: 3, title: "Slot 3", kind: .text),
            makeSlot(libraryId: clientes, order: 1, title: "Slot 1", kind: .text),
        ]

        for library in libraries {
            for order in 1...SlotStore.slotCount {
                guard !slots.contains(where: { $0.libraryId == library.id && $0.order == order }) else { continue }
                slots.append(makeSlot(libraryId: library.id, order: order, title: "Slot \(order)", kind: .text))
            }
        }

        let workspace = SlotsWorkspace(libraries: libraries, slots: slots, activeLibraryId: trabajo)
        workspaceStore.replaceWorkspace(workspace)
        workspaceStore.applyActiveLibrary(to: slotStore)

        historyStore.clear()
        historyStore.add(
            ClipItem(
                content: .text("macroled.com.ar/catalogo/arq"),
                createdAt: now.addingTimeInterval(-120),
                sourceAppName: "Safari"
            )
        )
        historyStore.add(
            ClipItem(
                content: .text("Hola, te paso el presupuesto actualizado…"),
                createdAt: now.addingTimeInterval(-120 * 60),
                sourceAppName: "Mail"
            )
        )
        historyStore.add(
            ClipItem(
                content: .text("calendly.com/estudio/30min"),
                createdAt: now.addingTimeInterval(-3600),
                sourceAppName: "Safari"
            )
        )

        UsageEventLog.shared.record("fixture_cargar_ejemplo", screen: "mac")
    }

    @MainActor
    static func resetToFresh(appState: AppState) {
        let fm = FileManager.default
        for url in [
            AppSupportDirectory.historyFile,
            AppSupportDirectory.slotsFile,
            AppSupportDirectory.workspaceFile,
            AppSupportDirectory.usageEventsFile,
        ] {
            try? fm.removeItem(at: url)
        }

        AppSettings.default.save()

        appState.historyStore.clear()
        appState.slotStore.replaceAll(Slot.defaultSlots())
        appState.libraryWorkspace.replaceWorkspace(SlotsWorkspace.empty())
        appState.libraryWorkspace.applyActiveLibrary(to: appState.slotStore)
        UsageEventLog.shared.clear()
        UsageEventLog.shared.record("fixture_empezar_de_cero", screen: "mac")

        appState.openOnboarding?()
    }
}
