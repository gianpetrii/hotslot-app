import AppKit
import Foundation

/// Monitorea NSPasteboard mediante polling de changeCount.
@MainActor
final class ClipboardService {
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private weak var historyStore: HistoryStore?

    /// Ignora el próximo cambio (escrituras propias).
    var suppressUntilChangeCount: Int = -1
    var isPaused = false

    init() {
        lastChangeCount = pasteboard.changeCount
    }

    func configure(historyStore: HistoryStore) {
        self.historyStore = historyStore
    }

    func start() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        guard !isPaused else { return }
        if current == suppressUntilChangeCount { return }
        guard let content = PasteboardHelper.readContent() else { return }

        let sourceApp = NSWorkspace.shared.frontmostApplication
        let item = ClipItem(
            content: content,
            sourceAppName: sourceApp?.localizedName,
            sourceAppBundleID: sourceApp?.bundleIdentifier
        )
        historyStore?.add(item)
    }

    /// Lee el clipboard actual sin agregar al historial.
    func currentContent() -> ClipContent? {
        PasteboardHelper.readContent()
    }
}
