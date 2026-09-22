import AppKit
import Foundation

/// Monitorea NSPasteboard mediante polling de changeCount.
@MainActor
final class ClipboardService {
    private let pasteboard = NSPasteboard.general
    private var lastCapturedChangeCount: Int
    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var appObservers: [NSObjectProtocol] = []
    private weak var historyStore: HistoryStore?

    /// Ignora el changeCount de una escritura propia (pegado desde HotSlot).
    var suppressUntilChangeCount: Int = -1
    var isPaused = false

    init() {
        lastCapturedChangeCount = pasteboard.changeCount
    }

    func configure(historyStore: HistoryStore) {
        self.historyStore = historyStore
    }

    func start() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        removeObservers()
        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            workspace.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.poll()
                }
            }
        )
        appObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.poll()
                }
            }
        )

        // Sincronizar con el portapapeles actual al arrancar
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        removeObservers()
    }

    /// Fuerza una lectura inmediata (útil tras copiar).
    func pollNow() {
        poll()
    }

    private func removeObservers() {
        let workspace = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            workspace.removeObserver(observer)
        }
        for observer in appObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        workspaceObservers.removeAll()
        appObservers.removeAll()
    }

    private func poll() {
        let current = pasteboard.changeCount
        guard current != lastCapturedChangeCount else { return }

        guard !isPaused else { return }

        if current == suppressUntilChangeCount {
            suppressUntilChangeCount = -1
            lastCapturedChangeCount = current
            return
        }

        guard let content = PasteboardHelper.readContent(from: pasteboard) else {
            // No avanzar: el contenido puede no estar listo aún; reintentar en el próximo tick
            return
        }

        lastCapturedChangeCount = current

        // Atribuir a la app que estaba al frente (puede haber cambiado ya)
        let sourceApp = NSWorkspace.shared.frontmostApplication
        let item = ClipItem(
            content: content,
            createdAt: Date(),
            sourceAppName: sourceApp?.localizedName,
            sourceAppBundleID: sourceApp?.bundleIdentifier
        )
        historyStore?.add(item)
    }

    /// Lee el clipboard actual sin agregar al historial.
    func currentContent() -> ClipContent? {
        PasteboardHelper.readContent(from: pasteboard)
    }
}
