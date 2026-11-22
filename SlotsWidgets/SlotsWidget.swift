import AppIntents
import SwiftUI
import WidgetKit

/// Qué biblioteca muestra el widget. Sin elegir: la primera.
struct SelectLibraryIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Biblioteca"
    static let description = IntentDescription("Elegí qué biblioteca mostrar.")

    @Parameter(title: "Biblioteca")
    var library: LibraryAppEntity?

    init() {}
}

/// Un slot tal como lo dibuja el widget: con su color de fondo del Mac y del iPhone.
struct WidgetSlot: Identifiable {
    let entity: SlotAppEntity
    let backgroundHex: String?
    var id: UUID { entity.id }
    var title: String { entity.title }
}

struct SlotsEntry: TimelineEntry {
    let date: Date
    let libraryId: UUID?
    let libraryName: String
    let slots: [WidgetSlot]
    var page: Int = 0
    /// Slot recién copiado desde el widget: se dibuja con ✓ unos segundos.
    var copiedId: UUID?
    /// Hacia dónde se pasó la última página: 1 adelante, -1 atrás.
    var direction = 1
}

/// Página que se está viendo, por biblioteca y tamaño. Un widget no scrollea: se cambia con las flechas.
enum WidgetPaging {
    private static var defaults: UserDefaults? { UserDefaults(suiteName: AppSupportDirectory.appGroupID) }

    static func key(library: UUID?, family: String) -> String { "widget.page.\(library?.uuidString ?? "-").\(family)" }
    static func page(for key: String) -> Int { defaults?.integer(forKey: key) ?? 0 }
    static func set(_ page: Int, for key: String) { defaults?.set(page, forKey: key) }
    static var direction: Int { defaults?.integer(forKey: "widget.page.direction") == -1 ? -1 : 1 }
    static func setDirection(_ value: Int) { defaults?.set(value, forKey: "widget.page.direction") }
}

/// Flechas de página del widget.
struct WidgetPageIntent: AppIntent {
    static let title: LocalizedStringResource = "Cambiar página"
    static let isDiscoverable = false

    @Parameter(title: "Clave") var key: String
    @Parameter(title: "Página") var page: Int

    init() {}
    init(key: String, page: Int) {
        self.key = key
        self.page = page
    }

    func perform() async throws -> some IntentResult {
        WidgetPaging.setDirection(page >= WidgetPaging.page(for: key) ? 1 : -1)
        WidgetPaging.set(max(page, 0), for: key)
        WidgetCenter.shared.reloadTimelines(ofKind: SlotsWidget.kind)
        return .result()
    }
}

/// Intención vacía: absorbe el toque en una flecha apagada.
struct WidgetNoopIntent: AppIntent {
    static let title: LocalizedStringResource = "Sin acción"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult { .result() }
}

struct SlotsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SlotsEntry { Self.sample }

    static var sample: SlotsEntry {
        func slot(_ title: String, _ hex: String?) -> WidgetSlot {
            WidgetSlot(entity: SlotAppEntity(id: UUID(), title: title, libraryName: "Trabajo"), backgroundHex: hex)
        }
        return SlotsEntry(
            date: .now,
            libraryId: nil,
            libraryName: "Trabajo",
            slots: [
                slot("Mi portfolio", SlotsPalette.brandGradientAsset),
                slot("Dirección estudio", nil),
                slot("Link de la reunión", "#111111"),
                slot("Gracias por escribir", nil),
            ]
        )
    }

    func snapshot(for configuration: SelectLibraryIntent, in context: Context) async -> SlotsEntry {
        await paged(entry(for: configuration, fallback: context.isPreview), family: context.family)
    }

    func timeline(for configuration: SelectLibraryIntent, in context: Context) async -> Timeline<SlotsEntry> {
        let current = await paged(entry(for: configuration, fallback: false), family: context.family)
        // Si se acaba de copiar un slot, el ✓ dura 2 s y después vuelve a la normalidad.
        let parts = UserDefaults(suiteName: AppSupportDirectory.appGroupID)?
            .string(forKey: CopySlotFromWidgetIntent.copiedKey)?.split(separator: "|")
        if let parts, parts.count == 2, let id = UUID(uuidString: String(parts[0])),
           let stamp = Double(parts[1]), Date().timeIntervalSince1970 - stamp < 2 {
            var copied = current
            copied.copiedId = id
            var after = current
            after = SlotsEntry(date: Date(timeIntervalSince1970: stamp + 2), libraryId: after.libraryId,
                               libraryName: after.libraryName, slots: after.slots, page: after.page, copiedId: nil, direction: after.direction)
            return Timeline(entries: [copied, after], policy: .never)
        }
        return Timeline(entries: [current], policy: .never)
    }

    /// La página sale del mismo lugar que escriben las flechas, y se lee acá para que el cambio se vea al primer toque.
    private func paged(_ entry: SlotsEntry, family: WidgetFamily) -> SlotsEntry {
        var entry = entry
        let pages = max(1, Int((Double(entry.slots.count) / Double(SlotsWidgetView.limit(for: family))).rounded(.up)))
        entry.direction = WidgetPaging.direction
        entry.page = min(WidgetPaging.page(for: WidgetPaging.key(library: entry.libraryId, family: "\(family)")), pages - 1)
        return entry
    }

    @MainActor
    private func entry(for configuration: SelectLibraryIntent, fallback: Bool) -> SlotsEntry {
        guard let workspace = WorkspaceSnapshot.load() else {
            return fallback ? Self.sample : SlotsEntry(date: .now, libraryId: nil, libraryName: "Slots", slots: [])
        }
        let libraries = WorkspaceSnapshot.sortedLibraries(workspace)
        let library = libraries.first { $0.id == configuration.library?.id }
            ?? libraries.first { $0.id == workspace.activeLibraryId }
            ?? libraries.first
        guard let library else { return SlotsEntry(date: .now, libraryId: nil, libraryName: "Slots", slots: []) }
        let slots = WorkspaceSnapshot.sortedSlots(in: library.id, workspace)
            .filter { $0.clipContent() != nil }
            .map { record -> WidgetSlot in
                var hex = record.cardBackgroundHex
                if case .text(let string) = record.clipContent(), let color = HexColor.normalized(string) { hex = color }
                return WidgetSlot(entity: SlotAppEntity(record, libraryName: library.name), backgroundHex: hex)
            }
        return SlotsEntry(date: .now, libraryId: library.id, libraryName: library.name, slots: slots)
    }
}

/// Widget de inicio y de pantalla de bloqueo con los slots de una biblioteca. Tocar uno lo copia.
struct SlotsWidget: Widget {
    nonisolated static let kind = "com.hotslot.app.ios.widget.slots"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectLibraryIntent.self, provider: SlotsProvider()) { entry in
            SlotsWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(slotsHex: 0xF2F2F0) }
        }
        .configurationDisplayName("Slots")
        .description("Los slots de una biblioteca. Tocá uno para copiarlo.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct SlotsWidgetView: View {
    let entry: SlotsEntry
    @Environment(\.widgetFamily) private var family

    private var pageKey: String { WidgetPaging.key(library: entry.libraryId, family: "\(family)") }
    private var pageCount: Int { max(1, Int((Double(entry.slots.count) / Double(limit)).rounded(.up))) }
    private var page: Int { entry.page }
    private var visibleSlots: ArraySlice<WidgetSlot> {
        let start = page * limit
        return entry.slots.dropFirst(start).prefix(limit)
    }

    private var limit: Int { Self.limit(for: family) }

    static func limit(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall, .accessoryRectangular: return 2
        case .systemLarge: return 10
        default: return 4
        }
    }

    /// Alto fijo de cada card: lo que sobra queda abajo, no se reparte.

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: lockScreen
            default: home
            }
        }
        // Tocar fuera de un slot o de las flechas abre Slots en la biblioteca del widget.
        .widgetURL(entry.libraryId.flatMap { URL(string: "hotslot://library/\($0.uuidString)") })
    }

    private var columnCount: Int { family == .systemMedium || family == .systemLarge ? 2 : 1 }

    /// Alto de cada card para que una página llena toque el borde inferior igual que la cabecera el superior.
    /// En una página incompleta las cards mantienen el mismo alto y el sobrante queda abajo.
    private func cardHeight(in height: CGFloat) -> CGFloat {
        let rows = CGFloat(max(1, Int((Double(limit) / Double(columnCount)).rounded(.up))))
        let available = height - Self.headerHeight - 8
        return max(32, (available - 8 * (rows - 1)) / rows)
    }

    private static let headerHeight: CGFloat = 22

    private var home: some View {
        GeometryReader { proxy in
            homeContent(cardHeight: cardHeight(in: proxy.size.height))
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }

    private func homeContent(cardHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(entry.libraryName)
                    .font(.custom("InterTight-Medium", fixedSize: 15))
                    .foregroundStyle(Color(slotsHex: 0x5E5A56))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if pageCount > 1 {
                    // El número de página cambia con cada toque: confirma que la flecha respondió.
                    // En el widget chico no entra: el nombre de la biblioteca necesita el lugar.
                    if family != .systemSmall {
                        Text("\(page + 1)/\(pageCount)")
                            .font(.custom("InterTight-Medium", fixedSize: 12))
                            .foregroundStyle(Color(slotsHex: 0x5E5A56))
                            .contentTransition(.numericText())
                    }
                    pageButton("chevron.left", target: page - 1, enabled: page > 0)
                    pageButton("chevron.right", target: page + 1, enabled: page < pageCount - 1)
                }
            }
            .frame(height: Self.headerHeight)
            if entry.slots.isEmpty {
                Spacer()
                Text("Guardá tu primer slot en Slots")
                    .font(.custom("InterTight-Medium", fixedSize: 15))
                    .foregroundStyle(Color(slotsHex: 0x111111))
                Spacer()
            } else {
                let columns = columnCount == 2
                    ? [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
                    : [GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(visibleSlots) { slot in
                        let light = SlotsPalette.prefersLightContent(hexString: slot.backgroundHex)
                        Button(intent: CopySlotFromWidgetIntent(slot: slot.entity)) {
                            let isCopied = entry.copiedId == slot.id
                            HStack(spacing: 6) {
                                if isCopied { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                                Text(isCopied ? "Copiado" : slot.title)
                            }
                                .font(.custom("InterTight-Medium", fixedSize: 15))
                                .foregroundStyle(light ? Color.white : Color(slotsHex: 0x111111))
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity, alignment: .bottomLeading)
                                .padding(10)
                                .frame(height: cardHeight, alignment: .bottomLeading)
                                .background { cardBackground(slot.backgroundHex) }
                                .scaleEffect(isCopied ? 0.97 : 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .id(page)
                .transition(.push(from: entry.direction >= 0 ? .trailing : .leading))
                Spacer(minLength: 0)
            }
        }
    }

    /// Flecha de página. Sin página de ese lado se ve apagada y el toque no hace nada (tampoco abre la app).
    @ViewBuilder
    private func pageButton(_ symbol: String, target: Int, enabled: Bool) -> some View {
        let label = Image(systemName: symbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color(slotsHex: 0x111111).opacity(enabled ? 1 : 0.25))
            .frame(width: 26, height: 22)
            .background(.white, in: Capsule())
        if enabled {
            Button(intent: WidgetPageIntent(key: pageKey, page: target)) { label }
                .buttonStyle(.plain)
        } else {
            // Un botón que no hace nada: así el toque no cae en el enlace que abre la app.
            Button(intent: WidgetNoopIntent()) { label }
                .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func cardBackground(_ hex: String?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        if SlotsPalette.isBrandGradient(hex) {
            shape.fill(Color(slotsHex: 0xE2501D))
        } else if let color = SlotsPalette.color(hexString: hex) {
            shape.fill(color)
        } else {
            shape.fill(.white)
        }
    }

    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.libraryName).font(.headline).widgetAccentable()
            ForEach(entry.slots.prefix(limit)) { slot in
                Button(intent: CopySlotFromWidgetIntent(slot: slot.entity)) {
                    Label(slot.title, systemImage: "doc.on.doc").font(.caption).lineLimit(1)
                }
                .buttonStyle(.plain)
            }
            if entry.slots.isEmpty { Text("Sin slots").font(.caption) }
        }
    }
}

