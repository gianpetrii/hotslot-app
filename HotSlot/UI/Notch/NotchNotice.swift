import AppKit

enum NotchNoticeKind: Equatable {
    case saved(slotIndex: Int, title: String?)
    case pasted(slotIndex: Int?, title: String?)
    case copied(slotIndex: Int?, title: String?)
    case emptySlot(index: Int)
    case noAccessibility
    case ready
    case plain(String)

    var line: String {
        switch self {
        case let .saved(index, title):
            if let title, !title.isEmpty {
                return "\(index) · \(title) · Guardado ✓"
            }
            return "\(index) · Guardado ✓"
        case let .pasted(index, title):
            if let index, let title, !title.isEmpty {
                return "\(index) · \(title) · Pegado ✓"
            }
            if let index {
                return "\(index) · Pegado ✓"
            }
            return "Pegado ✓"
        case let .copied(index, title):
            if let index, let title, !title.isEmpty {
                return "\(index) · \(title) · Copiado · ⌘V"
            }
            if let index {
                return "\(index) · Copiado · ⌘V"
            }
            return "Copiado · ⌘V para pegar"
        case let .emptySlot(index):
            return "\(index) · Slot vacío · Guardá con \(Self.saveShortcut(for: index))"
        case .noAccessibility:
            return "! \(BrandDisplay.name) no puede pegar · Dar permiso"
        case .ready:
            return "Listo · ⌘⇧V para ver tus slots"
        case let .plain(text):
            return text
        }
    }

    /// Avisos de guardar, pegar y copiar: número de slot, título y estado a la derecha.
    struct Structured {
        let badge: String?
        let title: String
        let status: String
        let showsCheck: Bool
        let orangeBadge: Bool
    }

    var structured: Structured? {
        switch self {
        case let .saved(index, title):
            return Structured(badge: "\(index)", title: title ?? "", status: "Guardado", showsCheck: true, orangeBadge: true)
        case let .pasted(index, title):
            return Structured(badge: index.map(String.init), title: title ?? "", status: "Pegado", showsCheck: false, orangeBadge: false)
        case let .copied(index, title):
            return Structured(badge: index.map(String.init), title: title ?? "", status: "Copiado", showsCheck: true, orangeBadge: false)
        default:
            return nil
        }
    }

    var isActionable: Bool {
        if case .noAccessibility = self { return true }
        return false
    }

    /// Negro para confirmar. Naranja cuando el aviso pide hacer algo.
    var usesActionColor: Bool {
        switch self {
        case .emptySlot, .noAccessibility:
            return true
        case .saved, .pasted, .copied, .ready, .plain:
            return false
        }
    }

    private static func saveShortcut(for index: Int) -> String {
        guard (1 ... 5).contains(index) else { return "⌘⌃" }
        return ["⌘⌃A", "⌘⌃S", "⌘⌃D", "⌘⌃Q", "⌘⌃W"][index - 1]
    }
}

/// Vista AppKit (evita bucle de constraints de `NSHostingView` en panel flotante).
private final class NotchPillView: NSView {
    var onAction: (() -> Void)?

    private let pill = NSView()
    private let label = NSTextField(labelWithString: "")
    private let badge = NSView()
    private let badgeLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let check = NSView()
    private let checkIcon = NSImageView()
    private var trackingArea: NSTrackingArea?
    private var structured: NotchNoticeKind.Structured?
    private var flush = false

    private static let height: CGFloat = 40
    private static let padding: CGFloat = 14
    private static let badgeSize: CGFloat = 22
    private static let checkSize: CGFloat = 18

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        pill.wantsLayer = true
        pill.layer?.backgroundColor = NotchPillView.quietColor
        pill.layer?.cornerCurve = .continuous

        Self.style(label, size: 11, weight: .medium, color: .white)
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        label.alignment = .center

        Self.style(titleLabel, size: 12, weight: .regular, color: NSColor.white.withAlphaComponent(0.75))
        titleLabel.lineBreakMode = .byTruncatingTail
        Self.style(statusLabel, size: 12, weight: .semibold, color: .white)

        badge.wantsLayer = true
        badge.layer?.cornerRadius = 6
        badge.layer?.cornerCurve = .continuous
        Self.style(badgeLabel, size: 11, weight: .semibold, color: .black)
        badgeLabel.alignment = .center

        check.wantsLayer = true
        check.layer?.backgroundColor = NotchPillView.actionColor
        check.layer?.cornerRadius = Self.checkSize / 2
        checkIcon.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 9, weight: .bold))
        checkIcon.contentTintColor = .white

        addSubview(pill)
        pill.addSubview(label)
        pill.addSubview(badge)
        badge.addSubview(badgeLabel)
        pill.addSubview(titleLabel)
        pill.addSubview(statusLabel)
        pill.addSubview(check)
        check.addSubview(checkIcon)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) no soportado")
    }

    private static func style(_ field: NSTextField, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
        field.font = NSFont.systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.isEditable = false
        field.isSelectable = false
        field.backgroundColor = .clear
        field.isBezeled = false
    }

    func configure(kind: NotchNoticeKind, flush: Bool, action: (() -> Void)?) {
        self.flush = flush
        structured = kind.structured
        onAction = kind.isActionable ? action : nil
        pill.layer?.backgroundColor = kind.usesActionColor ? Self.actionColor : Self.quietColor

        label.stringValue = kind.line
        label.isHidden = structured != nil
        let isStructured = structured != nil
        [badge, titleLabel, statusLabel].forEach { $0.isHidden = !isStructured }
        check.isHidden = !(structured?.showsCheck ?? false)

        if let structured {
            badge.isHidden = structured.badge == nil
            badgeLabel.stringValue = structured.badge ?? ""
            badge.layer?.backgroundColor = structured.orangeBadge ? Self.actionColor : NSColor.white.cgColor
            badgeLabel.textColor = structured.orangeBadge ? .white : .black
            titleLabel.stringValue = structured.title
            statusLabel.stringValue = structured.status
        }

        // Pegada al borde de arriba: solo se redondean las esquinas de abajo.
        pill.layer?.cornerRadius = flush ? 16 : 18
        pill.layer?.maskedCorners = flush
            ? [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            : [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        needsLayout = true
    }

    private static let quietColor = NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.07, alpha: 1).cgColor
    private static let actionColor = NSColor(srgbRed: 226 / 255, green: 80 / 255, blue: 29 / 255, alpha: 1).cgColor

    /// Tamaño que necesita el aviso para este contenido.
    static func size(for kind: NotchNoticeKind, maxWidth: CGFloat, flush: Bool) -> NSSize {
        if let structured = kind.structured {
            let titleFont = NSFont.systemFont(ofSize: 12)
            let statusFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
            let titleW = (structured.title as NSString).size(withAttributes: [.font: titleFont]).width
            let statusW = (structured.status as NSString).size(withAttributes: [.font: statusFont]).width
            var width = padding * 2 + statusW + 6
            if structured.badge != nil { width += badgeSize + 8 }
            if structured.showsCheck { width += checkSize + 6 }
            width += min(ceil(titleW), 180) + 16
            return NSSize(width: min(max(ceil(width), flush ? 260 : 200), maxWidth), height: height)
        }
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let rect = (kind.line as NSString).boundingRect(
            with: NSSize(width: maxWidth - 28, height: 200),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        return NSSize(
            width: min(max(ceil(rect.width) + 28, 120), maxWidth),
            height: max(ceil(rect.height) + 16, 36)
        )
    }

    override func layout() {
        super.layout()
        pill.frame = bounds
        guard structured != nil else {
            let paddingH: CGFloat = 14
            let paddingV: CGFloat = 8
            let textSize = label.sizeThatFits(NSSize(width: bounds.width - paddingH * 2, height: 200))
            label.frame = NSRect(
                x: paddingH,
                y: (bounds.height - textSize.height) / 2,
                width: bounds.width - paddingH * 2,
                height: max(textSize.height, bounds.height - paddingV * 2)
            ).integral
            return
        }

        let midY = bounds.height / 2
        var left = Self.padding
        if !badge.isHidden {
            badge.frame = NSRect(x: left, y: midY - Self.badgeSize / 2, width: Self.badgeSize, height: Self.badgeSize)
            badgeLabel.frame = NSRect(x: 0, y: (Self.badgeSize - 14) / 2, width: Self.badgeSize, height: 14)
            left += Self.badgeSize + 8
        }
        var right = bounds.width - Self.padding
        if !check.isHidden {
            right -= Self.checkSize
            check.frame = NSRect(x: right, y: midY - Self.checkSize / 2, width: Self.checkSize, height: Self.checkSize)
            checkIcon.frame = check.bounds
            right -= 6
        }
        let statusW = ceil(statusLabel.intrinsicContentSize.width)
        statusLabel.frame = NSRect(x: right - statusW, y: midY - 8, width: statusW, height: 16)
        titleLabel.frame = NSRect(x: left, y: midY - 8, width: max(0, statusLabel.frame.minX - 12 - left), height: 16)
    }

    override func mouseDown(with event: NSEvent) {
        onAction?()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func resetCursorRects() {
        if onAction != nil {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }
}

/// Barra negra que cuelga del notch (o bajo la barra de menú) para confirmar guardado, pegado o copiado.
/// Naranja si el aviso pide hacer algo.
@MainActor
final class NotchNoticeController {
    private var panel: NSPanel?
    private var pillView: NotchPillView?
    private var hideWorkItem: DispatchWorkItem?
    private var onOpenAccessibilitySettings: (() -> Void)?

    func configure(onOpenAccessibilitySettings: @escaping () -> Void) {
        self.onOpenAccessibilitySettings = onOpenAccessibilitySettings
    }

    func present(_ kind: NotchNoticeKind) {
        guard AppSettings.load().showNotchNotice else { return }

        hideWorkItem?.cancel()
        ensurePanel()
        guard let panel, let pillView else { return }

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let topInset = screen.safeAreaInsets.top
        let flush = topInset > 20
        let maxWidth = min(420, screen.visibleFrame.width - 32)
        let measured = NotchPillView.size(for: kind, maxWidth: maxWidth, flush: flush)

        pillView.configure(kind: kind, flush: flush) { [weak self] in
            self?.onOpenAccessibilitySettings?()
        }
        pillView.frame = NSRect(origin: .zero, size: measured)
        panel.contentView?.frame = NSRect(origin: .zero, size: measured)

        let x = screen.frame.midX - measured.width / 2
        let y: CGFloat = if flush {
            screen.frame.maxY - measured.height
        } else if topInset > 20 {
            screen.frame.maxY - topInset - measured.height - 6
        } else {
            screen.frame.maxY - NSStatusBar.system.thickness - measured.height - 10
        }

        panel.setFrame(NSRect(x: x, y: y, width: measured.width, height: measured.height), display: true)
        panel.alphaValue = 1
        panel.orderFront(nil)

        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        hideWorkItem = work
        // Los mensajes largos necesitan más tiempo de lectura.
        let seconds = kind.structured != nil ? 1.4 : min(4.0, max(1.8, Double(kind.line.count) * 0.05))
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func dismiss() {
        panel?.orderOut(nil)
        panel?.alphaValue = 0
    }

    private func ensurePanel() {
        guard panel == nil else { return }
        let pill = NotchPillView(frame: .zero)
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.hidesOnDeactivate = false
        p.isFloatingPanel = true
        p.contentView = pill
        panel = p
        pillView = pill
    }
}
