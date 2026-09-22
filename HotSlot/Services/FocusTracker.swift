import AppKit

/// Guarda la app que estaba al frente antes de que HotSlot tome foco.
@MainActor
final class FocusTracker {
    private(set) var lastFrontmostApp: NSRunningApplication?

    func capture() {
        lastFrontmostApp = NSWorkspace.shared.frontmostApplication
    }

    func clear() {
        lastFrontmostApp = nil
    }

    var targetApp: NSRunningApplication? {
        guard let app = lastFrontmostApp, !app.isTerminated else {
            return NSWorkspace.shared.frontmostApplication
        }
        // No pegar en nosotros mismos
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            return nil
        }
        return app
    }
}
