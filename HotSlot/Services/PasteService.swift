import AppKit
import Foundation

enum PasteResult {
    case pastedAutomatically
    case copiedNeedsManualPaste
    case failed(String)
}

/// Escribe al pasteboard y pega en la app objetivo vía Apple Events.
@MainActor
final class PasteService {
    private weak var clipboardService: ClipboardService?
    private weak var focusTracker: FocusTracker?
    var onShowToast: ((String?) -> Void)?

    func configure(clipboardService: ClipboardService, focusTracker: FocusTracker) {
        self.clipboardService = clipboardService
        self.focusTracker = focusTracker
    }

    @discardableResult
    func paste(content: ClipContent, targetApp: NSRunningApplication?) -> PasteResult {
        let changeCount = PasteboardHelper.copyContentToPasteboard(content)
        clipboardService?.suppressUntilChangeCount = changeCount

        if AppSettings.load().playSoundOnPaste {
            NSSound(named: "Pop")?.play()
        }

        guard let target = targetApp, !target.isTerminated else {
            onShowToast?("Contenido copiado al portapapeles")
            return .copiedNeedsManualPaste
        }

        target.activate()

        // Breve delay para que la app objetivo recupere foco
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            let result = Self.sendCommandV()
            if result {
                self?.onShowToast?(nil)
            } else {
                target.activate()
                self?.onShowToast?("Contenido listo — pulsa ⌘V para pegar")
            }
        }

        return .pastedAutomatically
    }

    func pasteFromSlot(index: Int, slotStore: SlotStore, focusTracker: FocusTracker) -> PasteResult {
        guard let content = slotStore.content(at: index) else {
            onShowToast?("El slot \(index) está vacío")
            return .failed("Slot vacío")
        }
        return paste(content: content, targetApp: focusTracker.targetApp)
    }

    func pasteFromHistory(item: ClipItem, focusTracker: FocusTracker) -> PasteResult {
        paste(content: item.content, targetApp: focusTracker.targetApp)
    }

    /// Simula ⌘V vía System Events (compatible con sandbox MAS).
    private static func sendCommandV() -> Bool {
        let script = """
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return false }
        let result = appleScript.executeAndReturnError(&error)
        return error == nil && result != nil
    }
}
