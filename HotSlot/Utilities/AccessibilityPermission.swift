import ApplicationServices
import AppKit
import os.log

/// Permiso de Accesibilidad, necesario para sintetizar ⌘V.
enum AccessibilityPermission {
    private static let logger = Logger(subsystem: "com.hotslot.app", category: "Accessibility")

    /// Último intento (visible en Ajustes → Permisos para depuración).
    private(set) static var lastDiagnostic: String = ""

    /// Evita que el tour se oculte al resignar foco mientras macOS muestra el aviso TCC.
    static var isAccessibilityPromptInFlight: Bool {
        Date() < promptGraceUntil
    }

    private static var promptGraceUntil = Date.distantPast

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestTrust(prompt: Bool = true) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = NSDictionary(dictionary: [
            key: prompt ? kCFBooleanTrue as Any : kCFBooleanFalse as Any,
        ])
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Activa la app, muestra el diálogo TCC (si macOS lo permite) y registra diagnóstico.
    static func requestAccessForPaste(focusWindow: NSWindow? = nil) {
        guard !isTrusted else {
            recordDiagnostic("omitido: ya concedido")
            return
        }

        if NSApp.activationPolicy() == .accessory {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
        focusWindow?.makeKeyAndOrderFront(nil)
        focusWindow?.makeMain()

        promptGraceUntil = Date().addingTimeInterval(4)

        let trustedBefore = isTrusted
        let bundlePath = Bundle.main.bundleURL.path
        let promptReturnedTrusted = requestTrust(prompt: true)
        let trustedAfter = isTrusted

        var lines = [
            "before=\(trustedBefore) after=\(trustedAfter)",
            "AXWithOptions=\(promptReturnedTrusted)",
            "policy=\(NSApp.activationPolicy().rawValue)",
            "bundle=\(Bundle.main.bundleURL.lastPathComponent)",
            "path=\(bundlePath)",
        ]
        if DevelopmentAppInstall.runsFromDerivedData {
            lines.append("nota=Run desde DerivedData → usá «Instalar en Aplicaciones» en Permisos y abrí /Applications/Slots.app.")
        } else if !DevelopmentAppInstall.runsFromApplications {
            lines.append("nota=Path fuera de /Applications; si no hay aviso TCC, activá el interruptor manualmente.")
        }
        recordDiagnostic(lines.joined(separator: " "))

        if !trustedAfter && !promptReturnedTrusted {
            logger.notice("TCC: si no hubo aviso, macOS ya lo mostró antes o hay que activar en Ajustes → Accesibilidad.")
        }

        promptGraceUntil = trustedAfter ? .distantPast : Date().addingTimeInterval(2)
    }

    static func openSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]
        for string in candidates {
            guard let url = URL(string: string) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
        NSWorkspace.shared.open(
            URL(fileURLWithPath: "/System/Applications/System Settings.app")
        )
    }

    private static func recordDiagnostic(_ message: String) {
        lastDiagnostic = message
        logger.info("\(message, privacy: .public)")
        #if DEBUG
        print("[Slots Accessibility] \(message)")
        #endif
    }
}

/// Lectura AX del foco: selección actual y si ese foco acepta pegar.
enum AccessibilityFocus {
    private static let blockedRoles: Set<String> = [
        "AXOutline",
        "AXTable",
        "AXList",
        "AXImage",
        "AXButton",
        "AXPopUpButton",
        "AXCheckBox",
        "AXRadioButton",
        "AXMenu",
        "AXMenuBar",
        "AXMenuItem",
        "AXToolbar",
        "AXTabGroup",
        "AXSplitter",
        "AXSlider",
        "AXStaticText",
        "AXLink",
        "AXDisclosureTriangle",
        "AXProgressIndicator",
        "AXBusyIndicator",
    ]

    static func selectedText(in app: NSRunningApplication? = nil) -> String? {
        guard AccessibilityPermission.isTrusted else { return nil }
        guard var node = focusedElement(in: app) else { return nil }
        for _ in 0..<8 {
            if let text = stringValue(node, kAXSelectedTextAttribute),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text
            }
            guard let parent = elementValue(node, kAXParentAttribute) else { break }
            node = parent
        }
        return nil
    }

    static func canAcceptPaste(in app: NSRunningApplication) -> Bool {
        guard AccessibilityPermission.isTrusted else { return true }
        guard let node = focusedElement(in: app) else { return true }
        let role = stringValue(node, kAXRoleAttribute) ?? ""
        return !blockedRoles.contains(role)
    }

    private static func focusedElement(in app: NSRunningApplication?) -> AXUIElement? {
        if let app {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            if let focused = elementValue(axApp, kAXFocusedUIElementAttribute) {
                return focused
            }
        }
        let system = AXUIElementCreateSystemWide()
        return elementValue(system, kAXFocusedUIElementAttribute)
    }

    private static func stringValue(_ element: AXUIElement, _ attribute: String) -> String? {
        guard let value = copyAttribute(element, attribute) else { return nil }
        return value as? String
    }

    private static func elementValue(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = copyAttribute(element, attribute) else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private static func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else { return nil }
        return value
    }
}
