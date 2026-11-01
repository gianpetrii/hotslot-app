import AppKit
import Foundation

/// Acciones del menú oculto (⌥ + clic derecho en la barra de menú).
@MainActor
final class StatusBarDeveloperActions: NSObject {
    weak var appState: AppState?

    @objc func devLoadSample() {
        guard let appState else { return }
        SampleDataFixture.loadExample(
            workspaceStore: appState.libraryWorkspace,
            slotStore: appState.slotStore,
            historyStore: appState.historyStore
        )
        appState.showToast("Datos de ejemplo cargados")
    }

    @objc func devResetFresh() {
        guard let appState else { return }
        SampleDataFixture.resetToFresh(appState: appState)
    }

    @objc func devExportEvents() {
        guard let url = UsageEventLog.shared.exportCSV() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        UsageEventLog.shared.record("fixture_exportar_eventos", screen: "mac")
    }
}

enum DeveloperMenuBuilder {
    @MainActor
    static func appendItems(to menu: NSMenu, target: StatusBarDeveloperActions) {
        menu.addItem(.separator())
        let header = NSMenuItem(title: "Prueba de usabilidad (⌥)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let load = NSMenuItem(title: "Cargar ejemplo", action: #selector(StatusBarDeveloperActions.devLoadSample), keyEquivalent: "")
        load.target = target
        menu.addItem(load)

        let reset = NSMenuItem(title: "Empezar de cero", action: #selector(StatusBarDeveloperActions.devResetFresh), keyEquivalent: "")
        reset.target = target
        menu.addItem(reset)

        let export = NSMenuItem(title: "Exportar eventos…", action: #selector(StatusBarDeveloperActions.devExportEvents), keyEquivalent: "")
        export.target = target
        menu.addItem(export)

        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            let versionItem = NSMenuItem(title: "Build \(version) (\(build))", action: nil, keyEquivalent: "")
            versionItem.isEnabled = false
            menu.addItem(versionItem)
        }
    }
}
