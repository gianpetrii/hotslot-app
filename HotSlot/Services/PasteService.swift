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
            logger.debug("Paste sin destino pasteable")
            FeedbackSound.play(.pasteFailed)
            onShowToast?("Contenido copiado al portapapeles")
            return .copiedNeedsManualPaste
        }

        logger.debug("Pegando en \(target.bundleIdentifier ?? "?", privacy: .public)")
        target.activate()
        schedulePaste(into: target, attempt: 0)

        return .pastedAutomatically
    }

    /// Espera a que la app destino esté al frente y manda ⌘V una sola vez (si se manda dos, pega doble).
    private func schedulePaste(into target: NSRunningApplication, attempt: Int) {
        let maxAttempts = 5
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else { return }

            if Self.frontIsNonPasteable() {
                FeedbackSound.play(.pasteFailed)
                self.onShowToast?("Contenido copiado al portapapeles")
                return
            }

            let front = NSWorkspace.shared.frontmostApplication
            let own = Bundle.main.bundleIdentifier
            let targetIsFront = front?.processIdentifier == target.processIdentifier
                || (front?.bundleIdentifier == target.bundleIdentifier && front?.bundleIdentifier != own)
            let stillUs = front?.bundleIdentifier == own

            if (targetIsFront || attempt >= maxAttempts), !stillUs {
                guard FocusTracker.pasteTarget(preferred: target) != nil else {
                    FeedbackSound.play(.pasteFailed)
                    self.onShowToast?("Contenido copiado al portapapeles")
                    return
                }
                guard HIDKeystroke.commandV() else {
                    FeedbackSound.play(.pasteFailed)
                    self.onShowToast?("Contenido listo — concedé Accesibilidad a HotSlot o pulsá ⌘V")
                    return
                }
                FeedbackSound.play(.pasteSuccess)
                self.onShowToast?(nil)
                return
            }

            if attempt >= maxAttempts {
                FeedbackSound.play(.pasteFailed)
                self.onShowToast?("Contenido copiado al portapapeles")
                return
            }

            target.activate()
            self.schedulePaste(into: target, attempt: attempt + 1)
        }
    }

    private static func frontIsNonPasteable() -> Bool {
        let own = Bundle.main.bundleIdentifier
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.bundleIdentifier != own else { return false }
        return FocusTracker.pasteTarget(preferred: front) == nil
    }

    func pasteFromSlot(index: Int, slotStore: SlotStore, focusTracker: FocusTracker) -> PasteResult {
        guard let content = slotStore.content(at: index) else {
            FeedbackSound.play(.pasteFailed)
            onShowToast?("El slot \(index) está vacío")
            return .failed("Slot vacío")
        }
        return paste(content: content, targetApp: focusTracker.pasteDestination())
    }

    func pasteFromHistory(item: ClipItem, focusTracker: FocusTracker) -> PasteResult {
        paste(content: item.content, targetApp: focusTracker.pasteDestination())
    }
}

enum HIDKeystroke {
    static func commandC() -> Bool { command(0x08) }
    static func commandV() -> Bool { command(0x09) }

    /// Sintetiza ⌘+tecla a nivel de sesión. Requiere Accesibilidad (TCC).
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
