import AppKit

enum NotchNoticeKind: Equatable {
    case saved(slotIndex: Int, title: String?)
    case pasted(slotIndex: Int?, title: String?)
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

    var isActionable: Bool {
        if case .noAccessibility = self { return true }
        return false
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
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        pill.wantsLayer = true
        pill.layer?.backgroundColor = NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.11, alpha: 1).cgColor
        pill.layer?.cornerRadius = 18
        pill.layer?.cornerCurve = .continuous

        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        label.alignment = .center
        label.isEditable = false
        label.isSelectable = false
        label.backgroundColor = .clear
        label.isBezeled = false

        addSubview(pill)
        pill.addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) no soportado")
    }

    func configure(line: String, actionable: Bool, action: (() -> Void)?) {
        label.stringValue = line
        onAction = actionable ? action : nil
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let paddingH: CGFloat = 14
        let paddingV: CGFloat = 8
        let maxTextWidth: CGFloat = min(420, bounds.width) - paddingH * 2
        let textSize = label.sizeThatFits(NSSize(width: maxTextWidth, height: 200))
        let pillWidth = min(max(textSize.width + paddingH * 2, 120), bounds.width)
        let pillHeight = max(textSize.height + paddingV * 2, 36)
        pill.frame = NSRect(x: (bounds.width - pillWidth) / 2, y: (bounds.height - pillHeight) / 2, width: pillWidth, height: pillHeight)
        label.frame = NSRect(x: paddingH, y: paddingV, width: pillWidth - paddingH * 2, height: pillHeight - paddingV * 2)
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

/// Píldora negra bajo el notch o la barra de menú.
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

        let actionable = kind.isActionable
        pillView.configure(line: kind.line, actionable: actionable) { [weak self] in
            self?.onOpenAccessibilitySettings?()
        }

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let maxWidth = min(420, screen.visibleFrame.width - 32)
        let measured = Self.measurePill(line: kind.line, maxWidth: maxWidth)
        pillView.frame = NSRect(origin: .zero, size: measured)
        panel.contentView?.frame = NSRect(origin: .zero, size: measured)

        let topInset = screen.safeAreaInsets.top
        let x = screen.frame.midX - measured.width / 2
        let y: CGFloat = if topInset > 20 {
            screen.frame.maxY - topInset - measured.height - 6
        } else {
            screen.frame.maxY - NSStatusBar.system.thickness - measured.height - 10
        }

        panel.setFrame(NSRect(x: x, y: y, width: measured.width, height: measured.height), display: true)
        panel.alphaValue = 1
        panel.orderFront(nil)

        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
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
        p.hasShadow = true
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.hidesOnDeactivate = false
        p.isFloatingPanel = true
        p.contentView = pill
        panel = p
        pillView = pill
    }

    private static func measurePill(line: String, maxWidth: CGFloat) -> NSSize {
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let textMax = maxWidth - 28
        let rect = (line as NSString).boundingRect(
            with: NSSize(width: textMax, height: 200),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        let width = min(max(ceil(rect.width) + 28, 120), maxWidth)
        let height = max(ceil(rect.height) + 16, 36)
        return NSSize(width: width, height: height)
    }
}
