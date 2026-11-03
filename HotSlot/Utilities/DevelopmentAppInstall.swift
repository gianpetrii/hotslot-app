import AppKit
import Foundation

/// Copia el build actual a `/Applications` para TCC estable (mismo bundle ID, path fijo).
enum DevelopmentAppInstall {
    static let applicationsURL = URL(fileURLWithPath: "/Applications/Slots.app")

    static var runsFromDerivedData: Bool {
        Bundle.main.bundleURL.path.contains("DerivedData")
    }

    static var runsFromApplications: Bool {
        Bundle.main.bundleURL.path.hasPrefix("/Applications/")
    }

    @discardableResult
    static func copyCurrentBuildToApplications() -> Result<Void, Error> {
        let source = Bundle.main.bundleURL
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: applicationsURL.path) {
                try fm.removeItem(at: applicationsURL)
            }
            try fm.copyItem(at: source, to: applicationsURL)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    static func openApplicationsCopy() {
        NSWorkspace.shared.openApplication(
            at: applicationsURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}
