import Foundation

/// Rutas en Application Support para persistencia local.
enum AppSupportDirectory {
    static let appName = "HotSlot"

    /// Override para tests unitarios.
    static var rootOverride: URL?

    static var root: URL {
        if let rootOverride { return rootOverride }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = base.appendingPathComponent(appName, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var images: URL {
        let url = root.appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var historyFile: URL {
        root.appendingPathComponent("history.json")
    }

    static var slotsFile: URL {
        root.appendingPathComponent("slots.json")
    }
}
