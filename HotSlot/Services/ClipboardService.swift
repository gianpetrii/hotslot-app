import AppKit
import Foundation
import os.log

/// Monitorea NSPasteboard mediante polling de changeCount.
@MainActor
@Observable
final class ClipboardService {
    private let pasteboard = NSPasteboard.general
    private let logger = Logger(subsystem: "com.hotslot.app", category: "Clipboard")

    private var lastCapturedChangeCount: Int
    private var pollTask: Task<Void, Never>?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var appObservers: [NSObjectProtocol] = []
    private weak var historyStore: HistoryStore?

    /// App que estaba activa justo antes del cambio de portapapeles.
    private var lastSourceApp: NSRunningApplication?

    /// Ignora el changeCount de una escritura propia (pegado desde HotSlot).
    var suppressUntilChangeCount: Int = -1
    var isPaused = false

    /// Estado visible en Ajustes → Depuración.
    var debugStatus: String = "Esperando copias…"

    init() {
        lastCapturedChangeCount = pasteboard.changeCount
    }

    func configure(historyStore: HistoryStore) {
        self.historyStore = historyStore
    }

    func start() {
        stop()

        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.poll()
                try? await Task.sleep(for: .milliseconds(200))
            }
        }

        let workspace = NSWorkspace.shared.notificationCenter

        workspaceObservers.append(
            workspace.addObserver(
                forName: NSWorkspace.didDeactivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                       app.bundleIdentifier != Bundle.main.bundleIdentifier {
                        self.lastSourceApp = app
                    }
                }
            }
        )

        workspaceObservers.append(
            workspace.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.poll() }
            }
        )

        appObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.poll() }
            }
        )

        logDebug("Monitor iniciado (changeCount: \(pasteboard.changeCount))")
        poll()
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        removeObservers()
    }

    func pollNow() {
        poll()
    }

    private func removeObservers() {
        let workspace = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers { workspace.removeObserver(observer) }
        for observer in appObservers { NotificationCenter.default.removeObserver(observer) }
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
            logDebug("Ignorado: escritura propia de HotSlot")
            return
        }

        let types = (pasteboard.types ?? []).map(\.rawValue).joined(separator: ", ")

        guard let content = PasteboardHelper.readContent(from: pasteboard) else {
            logDebug("changeCount \(current) — lectura falló. Tipos: [\(types)]")
            return
        }

        lastCapturedChangeCount = current

        let sourceApp = lastSourceApp ?? NSWorkspace.shared.frontmostApplication
        let item = ClipItem(
            content: content,
            createdAt: Date(),
            sourceAppName: sourceApp?.localizedName,
            sourceAppBundleID: sourceApp?.bundleIdentifier
        )
        historyStore?.add(item)

        let preview = content.previewText
        logDebug("Capturado: \"\(preview)\" desde \(sourceApp?.localizedName ?? "?")")
    }

    func currentContent() -> ClipContent? {
        PasteboardHelper.readContent(from: pasteboard)
    }

    private func logDebug(_ message: String) {
        debugStatus = message
        logger.debug("\(message)")
    }
}
