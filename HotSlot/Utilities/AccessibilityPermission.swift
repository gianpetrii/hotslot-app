import ApplicationServices
import AppKit

/// Permiso de Accesibilidad, necesario para sintetizar ⌘V.
enum AccessibilityPermission {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestTrust(prompt: Bool = true) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
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

    /// Texto seleccionado en la app (o en el foco del sistema). Vacío = no hay selección.
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

    /// Si el foco de esa app puede recibir un pegado de texto.
    /// Chrome/Cursor son AXWebArea: hay que dejar pasar ⌘V. Solo bloqueamos controles claramente no editables.
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
