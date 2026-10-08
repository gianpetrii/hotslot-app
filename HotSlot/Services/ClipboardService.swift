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

    /// Último clip que realmente capturamos (para no re-leer texto viejo del pasteboard).
    private var lastCapturedContent: ClipContent?

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
            lastCapturedContent = PasteboardHelper.readContent(
                from: pasteboard,
                preferringChangeFrom: lastCapturedContent
            )
            logDebug("Ignorado: escritura propia de HotSlot")
            return
        }

        ingestPasteboardIfNeeded(changeCount: current)
    }

    func currentContent() -> ClipContent? {
        ingestPasteboardIfNeeded(changeCount: pasteboard.changeCount)
        return lastCapturedContent
            ?? PasteboardHelper.readContent(from: pasteboard, preferringChangeFrom: lastCapturedContent)
    }

    /// Atajo de guardar: la selección actual, no el último clip del historial.
    func captureSelection() async -> ClipContent? {
        let source = NSWorkspace.shared.frontmostApplication
        if source?.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastSourceApp = source
        }

        if let text = AccessibilityFocus.selectedText(in: source),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            logDebug("Guardar slot: selección AX \"\(text.prefix(80))\"")
            recordExternalContent(.text(text), source: source)
            return .text(text)
        }

        let before = pasteboard.changeCount
        logDebug("Guardar slot: sin AX, enviando ⌘C (changeCount \(before))")
        guard HIDKeystroke.commandC() else { return nil }

        for _ in 0..<24 {
            try? await Task.sleep(for: .milliseconds(25))
            if pasteboard.changeCount != before {
                ingestPasteboardIfNeeded(changeCount: pasteboard.changeCount)
                logDebug("Guardar slot: portapapeles actualizado (\(pasteboard.changeCount))")
                return lastCapturedContent
            }
        }
        logDebug("Guardar slot: no hubo selección ni ⌘C")
        return nil
    }

    private func recordExternalContent(_ content: ClipContent, source: NSRunningApplication?) {
        if content != lastCapturedContent {
            let item = ClipItem(
                content: content,
                createdAt: Date(),
                sourceAppName: source?.localizedName,
                sourceAppBundleID: source?.bundleIdentifier
            )
            historyStore?.add(item)
            logDebug("Capturado: \"\(content.previewText)\" desde \(source?.localizedName ?? "?")")
        }
        lastCapturedContent = content
        let change = PasteboardHelper.write(content: content)
        suppressUntilChangeCount = change
        lastCapturedChangeCount = change
    }

    private func ingestPasteboardIfNeeded(changeCount current: Int) {
        let types = (pasteboard.types ?? []).map(\.rawValue).joined(separator: ", ")
        let content = PasteboardHelper.readContent(
            from: pasteboard,
            preferringChangeFrom: lastCapturedContent
        )
        guard let content else {
            if current != lastCapturedChangeCount {
                logDebug("changeCount \(current) — lectura falló. Tipos: [\(types)]")
            }
            return
        }

        if current == lastCapturedChangeCount, content == lastCapturedContent {
            return
        }

        lastCapturedChangeCount = current
        lastCapturedContent = content

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

    private func logDebug(_ message: String) {
        debugStatus = message
        logger.debug("\(message)")
    }
}
