import AppKit

/// Guarda la app que estaba al frente antes de que HotSlot tome foco.
@MainActor
final class FocusTracker {
    private(set) var lastFrontmostApp: NSRunningApplication?
    private var observers: [NSObjectProtocol] = []

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers { center.removeObserver(observer) }
    }

    func start() {
        stop()
        remember(NSWorkspace.shared.frontmostApplication)

        let center = NSWorkspace.shared.notificationCenter
        observers.append(
            center.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                    self?.remember(app)
                }
            }
        )
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers { center.removeObserver(observer) }
        observers.removeAll()
    }

    func capture() {
        remember(NSWorkspace.shared.frontmostApplication)
    }

    func clear() {
        lastFrontmostApp = nil
    }

    var targetApp: NSRunningApplication? {
        Self.pasteTarget(preferred: lastFrontmostApp)
    }

    /// Destino real al pegar: si ahora mismo está Finder/escritorio, no uses un Cursor viejo.
    static func pasteTarget(preferred: NSRunningApplication?) -> NSRunningApplication? {
        let own = Bundle.main.bundleIdentifier
        let front = NSWorkspace.shared.frontmostApplication

        if let front, front.bundleIdentifier != own, !isPasteable(front, excluding: own) {
            return nil
        }

        if let app = preferred, isPasteable(app, excluding: own) {
            return app
        }
        if let front, isPasteable(front, excluding: own) {
            return front
        }
        return nil
    }

    /// Finder, Dock, etc. no son un campo de texto: copiar sí, pegar automático no.
    private static let nonPasteableBundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.loginwindow",
        "com.apple.systemuiserver",
        "com.apple.Spotlight",
        "com.apple.controlcenter",
        "com.apple.NotificationCenter",
        "com.apple.WindowManager",
    ]

    private func remember(_ app: NSRunningApplication?) {
        guard let app else { return }
        if app.bundleIdentifier == Bundle.main.bundleIdentifier { return }
        lastFrontmostApp = app
    }

    private static func isPasteable(_ app: NSRunningApplication, excluding ownBundle: String?) -> Bool {
        guard !app.isTerminated else { return false }
        guard let bundle = app.bundleIdentifier, bundle != ownBundle else { return false }
        return !nonPasteableBundleIDs.contains(bundle)
    }
}
