import AppKit
import Foundation
import os.log

enum PasteResult {
    case pastedAutomatically
    case copiedNeedsManualPaste
    case failed(String)
}

/// Escribe al pasteboard y pega en la app objetivo sintetizando ⌘V.
@MainActor
final class PasteService {
    private weak var clipboardService: ClipboardService?
    private weak var focusTracker: FocusTracker?
    private let logger = Logger(subsystem: "com.hotslot.app", category: "Paste")
    var onShowToast: ((String?) -> Void)?

    func configure(clipboardService: ClipboardService, focusTracker: FocusTracker) {
        self.clipboardService = clipboardService
        self.focusTracker = focusTracker
    }

    @discardableResult
    func paste(content: ClipContent, targetApp: NSRunningApplication?) -> PasteResult {
        let changeCount = PasteboardHelper.copyContentToPasteboard(content)
        clipboardService?.suppressUntilChangeCount = changeCount

        let target = FocusTracker.pasteTarget(preferred: targetApp)
        guard let target else {
            FeedbackSound.play(.pasteFailed)
            onShowToast?("Contenido copiado al portapapeles")
            return .copiedNeedsManualPaste
        }

        target.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            if let front = NSWorkspace.shared.frontmostApplication,
               front.bundleIdentifier != Bundle.main.bundleIdentifier,
               FocusTracker.pasteTarget(preferred: front) == nil {
                FeedbackSound.play(.pasteFailed)
                self.onShowToast?("Contenido copiado al portapapeles")
                return
            }
            guard HIDKeystroke.commandV() else {
                FeedbackSound.play(.pasteFailed)
                self.onShowToast?("Contenido listo — pulsa ⌘V para pegar")
                return
            }
            FeedbackSound.play(.pasteSuccess)
            self.onShowToast?(nil)
        }

        return .pastedAutomatically
    }

    func pasteFromSlot(index: Int, slotStore: SlotStore, focusTracker: FocusTracker) -> PasteResult {
        guard let content = slotStore.content(at: index) else {
            FeedbackSound.play(.pasteFailed)
            onShowToast?("El slot \(index) está vacío")
            return .failed("Slot vacío")
        }
        return paste(content: content, targetApp: focusTracker.targetApp)
    }

    func pasteFromHistory(item: ClipItem, focusTracker: FocusTracker) -> PasteResult {
        paste(content: item.content, targetApp: focusTracker.targetApp)
    }

}

enum HIDKeystroke {
    static func commandC() -> Bool { command(0x08) }
    static func commandV() -> Bool { command(0x09) }

    /// Sintetiza ⌘+tecla a nivel de sesión. No usa System Events (evita el error 1002).
    private static func command(_ virtualKey: CGKeyCode) -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitLocalKeyboardEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        source?.localEventsSuppressionInterval = 0

        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
        else {
            return false
        }

        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}
