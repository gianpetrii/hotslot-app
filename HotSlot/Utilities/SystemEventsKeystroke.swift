import AppKit
import os.log

/// Simula ⌘C / ⌘V vía Automatización (System Events), sin Accesibilidad.
enum SystemEventsKeystroke {
    private static let logger = Logger(subsystem: "com.hotslot.app", category: "Automation")

    static func commandC() -> Bool {
        send(key: "c")
    }

    static func commandV() -> Bool {
        send(key: "v")
    }

    private static func send(key: String) -> Bool {
        let script = """
        tell application "System Events"
            keystroke "\(key)" using command down
        end tell
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return false }
        appleScript.executeAndReturnError(&error)
        if let error {
            logger.error("System Events keystroke failed: \(String(describing: error), privacy: .public)")
            return false
        }
        return true
    }
}
