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

        guard let target = targetApp, !target.isTerminated else {
            onShowToast?("Contenido copiado al portapapeles")
            return .copiedNeedsManualPaste
        }

        target.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            if Self.sendCommandV() {
                if AppSettings.load().playSoundOnPaste {
                    NSSound(named: "Pop")?.play()
                }
                self.onShowToast?(nil)
            } else {
                target.activate()
                if AccessibilityPermission.isTrusted {
                    self.onShowToast?("Contenido listo — pulsa ⌘V para pegar")
                } else {
                    self.logger.warning("⌘V bloqueado: el proceso actual no está en Accesibilidad")
                    self.onShowToast?("Sin Accesibilidad — el contenido quedó copiado, pegá con ⌘V")
                }
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

    /// Sintetiza ⌘V a nivel de sesión. No usa System Events (evita el error 1002).
    private static func sendCommandV() -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitLocalKeyboardEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        source?.localEventsSuppressionInterval = 0

        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        else {
            return false
        }

        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)

        // Si el proceso no está trusted, macOS descarta los eventos sin error.
        return AccessibilityPermission.isTrusted
    }
}
