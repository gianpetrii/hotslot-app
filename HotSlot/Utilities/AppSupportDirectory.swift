import Darwin
import Foundation

/// Rutas en Application Support para persistencia local.
enum AppSupportDirectory {
    static let appName = "HotSlot"

    /// Override para tests unitarios.
    static var rootOverride: URL?

    private static let sandboxContainerMigrationKey = "hotslot.migrated.fromSandboxContainer.v1"

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

    static var richText: URL {
        let url = root.appendingPathComponent("RichText", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var historyFile: URL {
        root.appendingPathComponent("history.json")
    }

    static var slotsFile: URL {
        root.appendingPathComponent("slots.json")
    }

    static var workspaceFile: URL {
        root.appendingPathComponent("libraries-workspace.json")
    }

    static var usageEventsFile: URL {
        root.appendingPathComponent("usage-events.json")
    }

    /// Hasta 0.20.x la app corría en sandbox: datos y preferencias vivían en `~/Library/Containers/<bundle>`.
    /// Se copian una sola vez; el contenedor es la versión más nueva, así que pisa lo que haya.
    static func migrateFromSandboxContainerIfNeeded() {
        guard rootOverride == nil,
              ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil else { return }
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: sandboxContainerMigrationKey) else { return }
        defer { defaults.set(true, forKey: sandboxContainerMigrationKey) }

        guard let bundleID = Bundle.main.bundleIdentifier,
              let realHome = realUserHomeDirectory() else { return }
        let containerLibrary = realHome
            .appendingPathComponent("Library/Containers/\(bundleID)/Data/Library", isDirectory: true)

        copyReplacing(
            from: containerLibrary.appendingPathComponent("Application Support/\(appName)", isDirectory: true),
            to: root
        )

        let preferences = containerLibrary.appendingPathComponent("Preferences/\(bundleID).plist")
        if let values = NSDictionary(contentsOf: preferences) as? [String: Any] {
            for (key, value) in values where key != sandboxContainerMigrationKey {
                defaults.set(value, forKey: key)
            }
        }
    }

    /// Archivos: reemplaza. Carpetas (p. ej. `Images`): fusiona.
    private static func copyReplacing(from source: URL, to destination: URL) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return }
        try? fm.createDirectory(at: destination, withIntermediateDirectories: true)

        for item in items {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory {
                copyReplacing(from: item, to: target)
            } else {
                try? fm.removeItem(at: target)
                try? fm.copyItem(at: item, to: target)
            }
        }
    }

    /// `getpwuid` da el home real aunque el proceso tenga otro `HOME`.
    private static func realUserHomeDirectory() -> URL? {
        guard let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir else { return nil }
        return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
    }
}

