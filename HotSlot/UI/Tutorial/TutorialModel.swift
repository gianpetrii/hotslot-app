import KeyboardShortcuts
import SwiftUI

/// Elementos del panel de muestra que el recorrido puede resaltar.
enum TutorialTarget: Hashable {
    case title, grid, slot1, slot2, history, search, pills, saveButton, settingsButton
}

/// Recortes de texto: palabras sueltas o teclas (cada carácter va en su propia tecla).
enum TutorialToken {
    case text(String)
    case keys(String)
}

enum TutorialBalloonSide {
    case right, left, above, below
}

struct TutorialStep {
    let target: TutorialTarget
    let side: TutorialBalloonSide
    let title: String
    let text: [TutorialToken]
    /// Radio del hueco: 28 en grilla, slots e historial; 32 en pills, botones y buscador.
    let holeRadius: CGFloat
    var showsContextMenu = false
}

enum TutorialPhase: Hashable {
    case welcome
    case popup
    case step(Int)
    case closing
    /// Después del recorrido: pasos de configuración, solo si hacen falta.
    case permission
    case privacy
}

/// Estado del tutorial de primera vez. Todo vive acá, en memoria: nunca toca los slots ni el historial del usuario.
@Observable
@MainActor
final class TutorialModel {
    var phase: TutorialPhase = .welcome

    /// Cierra el tutorial del todo (después del último paso que corresponda).
    var onClose: (() -> Void)?

    /// Accesibilidad: hace falta para pegar en otras apps. Se pide una sola vez.
    var permissionGranted = AccessibilityPermission.isTrusted
    private let needsPermission = !AccessibilityPermission.isTrusted
    /// Uso anónimo (opt-in): se pregunta una sola vez, apagado por defecto.
    private let needsPrivacy = Telemetry.isConfigured && !AppSettings.load().hasAnsweredAnalyticsPrompt
    var shareUsage = false
    /// La vista lo completa: dispara el pedido del sistema (así Enter hace lo mismo que el botón).
    var requestPermission: (() -> Void)?

    let steps: [TutorialStep]

    init() {
        let save1 = Self.keys(for: .copyToSlotName(1), fallback: "⌘⌃A")
        let paste1 = Self.keys(for: .pasteSlotName(1), fallback: "⌘⇧A")
        steps = [
            TutorialStep(
                target: .grid, side: .right, title: "Tus slots",
                text: [.text("Cada slot guarda algo que mandás seguido: un link, un texto, una imagen. Hacé clic en un slot lleno y se pega en la app donde estabas.")],
                holeRadius: 28
            ),
            TutorialStep(
                target: .slot1, side: .right, title: "Guardá y pegá con atajos",
                text: [
                    .text("Seleccioná algo y apretá "), .keys(save1),
                    .text(" para guardarlo en el slot 1. Con "), .keys(paste1),
                    .text(" lo pegás donde estés. A · S · D · Q · W son los slots 1 a 5."),
                ],
                holeRadius: 28
            ),
            TutorialStep(
                target: .history, side: .left, title: "Lo último que copiaste",
                text: [.text("El historial guarda lo que vas copiando. Arrastrá un ítem a un slot y queda guardado.")],
                holeRadius: 28
            ),
            TutorialStep(
                target: .slot2, side: .below, title: "Cambiá nombre y orden",
                text: [.text("Clic derecho en un slot para renombrarlo, cambiarle el color, reemplazar lo que tiene, moverlo a otra biblioteca o vaciarlo. Arrastralo para cambiarlo de lugar.")],
                holeRadius: 28, showsContextMenu: true
            ),
            TutorialStep(
                target: .search, side: .below, title: "Encontrá todo",
                text: [
                    .text("Buscá en tus slots y en el historial con "), .keys("⌘F"),
                    .text(", o empezá a escribir con el panel abierto."),
                ],
                holeRadius: 32
            ),
            TutorialStep(
                target: .pills, side: .above, title: "Ordená por tema",
                text: [.text("Cambiá de biblioteca tocando su nombre. Con el + creás una nueva y le ponés el nombre que quieras.")],
                holeRadius: 32
            ),
            TutorialStep(
                target: .saveButton, side: .above, title: "Más slots",
                text: [.text("Guardá lo que tenés copiado en un slot nuevo. ¿Necesitás más de 5? Scrolleá la grilla y tocá «Nuevo slot».")],
                holeRadius: 32
            ),
            TutorialStep(
                target: .settingsButton, side: .below, title: "Tus ajustes",
                text: [.text("Cambiá tus atajos, revisá los permisos y volvé a ver este recorrido cuando quieras.")],
                holeRadius: 32
            ),
        ]
    }

    var togglePanelKeys: String { Self.keys(for: .togglePanel, fallback: "⌘⇧V") }

    var stepCount: Int { steps.count }

    /// Los atajos que se muestran son los que la persona tiene configurados.
    private static func keys(for name: KeyboardShortcuts.Name, fallback: String) -> String {
        guard let description = KeyboardShortcuts.Shortcut(name: name)?.description else { return fallback }
        // Como en el diseño de Dante: ⌘ primero, después el resto de las teclas.
        return description.contains("⌘") ? "⌘" + description.replacingOccurrences(of: "⌘", with: "") : description
    }

    // MARK: - Navegación

    func startTour() {
        phase = .step(0)
    }

    func next() {
        switch phase {
        case .popup: startTour()
        case .step(let index): phase = index + 1 < steps.count ? .step(index + 1) : .closing
        default: break
        }
    }

    /// Termina el recorrido (al final, al saltear o con «Manos a la obra»): sigue con la configuración que falte.
    func close() {
        switch phase {
        case .permission:
            if needsPrivacy { phase = .privacy } else { finish() }
        case .privacy:
            finish()
        default:
            if needsPermission { phase = .permission }
            else if needsPrivacy { phase = .privacy }
            else { finish() }
        }
    }

    func finish() {
        if needsPrivacy, phase == .privacy {
            var settings = AppSettings.load()
            settings.analyticsEnabled = shareUsage
            settings.hasAnsweredAnalyticsPrompt = true
            settings.save()
            Telemetry.consentChanged()
        }
        onClose?()
    }

    func back() {
        if case .step(let index) = phase, index > 0 { phase = .step(index - 1) }
    }
}
