import Darwin
import Foundation

/// Rutas en Application Support para persistencia local.
enum AppSupportDirectory {
    static let appName = "HotSlot"

    /// Override para tests unitarios.
    static var rootOverride: URL?

    private static let unsandboxedMigrationKey = "hotslot.migrated.unsandboxed.support.v1"

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

    /// Copia historial/slots/imágenes desde `~/Library/Application Support/HotSlot` al contenedor sandbox.
    static func migrateUnsandboxedIfNeeded() {
        guard ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil else { return }
        guard !UserDefaults.standard.bool(forKey: unsandboxedMigrationKey) else { return }
        UserDefaults.standard.set(true, forKey: unsandboxedMigrationKey)

        guard let realHome = realUserHomeDirectory() else { return }
        let source = realHome.appendingPathComponent("Library/Application Support/\(appName)", isDirectory: true)
        let destination = root
        let fm = FileManager.default
        guard source.standardizedFileURL != destination.standardizedFileURL,
              fm.fileExists(atPath: source.path) else { return }

        copyIfMissing(from: source.appendingPathComponent("history.json"), to: historyFile)
        copyIfMissing(from: source.appendingPathComponent("slots.json"), to: slotsFile)

        let sourceImages = source.appendingPathComponent("Images", isDirectory: true)
        guard let files = try? fm.contentsOfDirectory(at: sourceImages, includingPropertiesForKeys: nil) else { return }
        let destImages = images
        for file in files {
            copyIfMissing(from: file, to: destImages.appendingPathComponent(file.lastPathComponent))
        }
    }

    private static func copyIfMissing(from source: URL, to destination: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path),
              !fm.fileExists(atPath: destination.path) else { return }
        try? fm.copyItem(at: source, to: destination)
    }

    /// En sandbox, `homeDirectoryForCurrentUser` es el contenedor; `getpwuid` da el home real.
    private static func realUserHomeDirectory() -> URL? {
        guard let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir else { return nil }
        return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
    }
}

