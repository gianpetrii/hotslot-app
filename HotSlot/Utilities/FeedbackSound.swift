import AppKit

/// Sonidos del sistema, uno por tipo de resultado. Silencio si el usuario apagó el toggle.
enum FeedbackSound {
    case pasteSuccess
    case pasteFailed
    case saved

    private var systemName: String {
        switch self {
        // Nombres en disco; en Ajustes del Sistema: Tink=Boop, Pop=Bubble, Funk=Funky.
        case .pasteSuccess: return "Tink"
        case .pasteFailed: return "Pop"
        case .saved: return "Funk"
        }
    }

    private static var playing: NSSound?

    static func play(_ sound: FeedbackSound) {
        guard AppSettings.load().playSoundOnPaste else { return }
        let url = URL(fileURLWithPath: "/System/Library/Sounds/\(sound.systemName).aiff")
        let instance = NSSound(contentsOf: url, byReference: true)
        playing = instance
        instance?.play()
    }
}
