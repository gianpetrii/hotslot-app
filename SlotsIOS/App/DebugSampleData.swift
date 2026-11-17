#if DEBUG
import UIKit

/// Datos de ejemplo del handoff para probar pantallas. Solo en Debug, con el argumento `-slotsSampleData`.
enum DebugSampleData {
    @MainActor
    static func loadIfRequested(into store: LibraryWorkspaceStore) {
        guard ProcessInfo.processInfo.arguments.contains("-slotsSampleData") else { return }
        let libraryId = store.workspace.activeLibraryId
        guard !store.slots(for: libraryId).contains(where: { $0.title == "Mi portfolio" }) else { return }

        var items: [(String, ClipContent, String?)] = []
        if let image = saveImage(size: CGSize(width: 1080, height: 1350), name: "ejemplo-flyer.png") {
            items.append(("Flyer Expo", image, nil))
        }
        items.append(("Mi portfolio", .text("https://www.behance.net/estudio"), nil))
        items.append(("Pedido de presupuesto", .text("Hola, gracias por escribir. Para pasarte un presupuesto necesito saber qué piezas necesitás y para cuándo."), nil))
        items.append(("Dirección estudio", .text("Echeverría 752"), nil))
        if let image = saveImage(size: CGSize(width: 1920, height: 1080), name: "ejemplo-story.png") {
            items.append(("Story Expo", image, nil))
        }
        items.append(("Gracias por escribir", .text("Gracias por escribir, te respondo en el día."), "#1C1C1C"))
        items.append(("Link de la reunión", .text("https://meet.google.com/abc-defg-hij"), nil))
        items.append(("Naranja de marca", .text("#E2501D"), nil))
        items.append(("Contrato.pdf", .file(path: ClipContent.remoteOnlyPathPrefix + "Contrato.pdf", bookmark: nil), nil))

        for (title, content, background) in items {
            guard let order = store.addSlot(toLibraryId: libraryId, content: content, title: title) else { continue }
            if let background {
                store.updateActiveSlot(order: order) { $0.cardBackgroundHex = background }
            }
        }
    }

    private static func saveImage(size: CGSize, name: String) -> ClipContent? {
        guard let source = UIImage(named: "DegradeNaranja") else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let data = UIGraphicsImageRenderer(size: size, format: format).pngData { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }
        let url = AppSupportDirectory.images.appendingPathComponent(name)
        guard (try? data.write(to: url, options: .atomic)) != nil else { return nil }
        return .image(fileName: name)
    }
}
#endif
