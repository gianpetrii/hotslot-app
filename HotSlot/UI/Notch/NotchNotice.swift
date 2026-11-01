import AppKit
import SwiftUI

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

struct NotchNoticePill: View {
    let kind: NotchNoticeKind
    let onAction: () -> Void

    var body: some View {
        Group {
            if kind.isActionable {
                Button(action: onAction) {
                    pillLabel
                }
                .buttonStyle(.plain)
            } else {
                pillLabel
            }
        }
        .accessibilityLabel(kind.line)
    }

    private var pillLabel: some View {
        Text(kind.line)
            .font(SlotsFont.etiqueta)
            .foregroundStyle(.white)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(SlotsColor.cardOscura)
            }
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }
}

/// Píldora negra bajo el notch o la barra de menú (flujos Mac › aviso en el notch).
@MainActor
final class NotchNoticeController {
    private var panel: NSPanel?
    private var hosting: NSHostingController<NotchNoticePill>?
    private var hideWorkItem: DispatchWorkItem?
    private var onOpenAccessibilitySettings: (() -> Void)?

    func configure(onOpenAccessibilitySettings: @escaping () -> Void) {
        self.onOpenAccessibilitySettings = onOpenAccessibilitySettings
    }

    func present(_ kind: NotchNoticeKind) {
        guard AppSettings.load().showNotchNotice else { return }

        hideWorkItem?.cancel()
        ensurePanel()

        hosting?.rootView = NotchNoticePill(kind: kind) { [weak self] in
            if kind.isActionable {
                self?.onOpenAccessibilitySettings?()
            }
        }
        relayoutPanel()

        panel?.alphaValue = 0
        panel?.orderFrontRegardless()

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduceMotion {
            panel?.alphaValue = 1
        } else {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel?.animator().alphaValue = 1
            }
        }

        let work = DispatchWorkItem { [weak self] in self?.dismissAnimated() }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func ensurePanel() {
        guard panel == nil else { return }
        let rect = CGRect(x: 0, y: 0, width: 320, height: 44)
        let p = NSPanel(
            contentRect: rect,
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
        p.becomesKeyOnlyIfNeeded = true

        let host = NSHostingController(
            rootView: NotchNoticePill(kind: .plain("")) {}
        )
        host.safeAreaRegions = []
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = NSColor.clear.cgColor
        p.contentViewController = host

        panel = p
        hosting = host
    }

    private func relayoutPanel() {
        guard let panel, let hosting else { return }
        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first!

        let maxWidth = min(420, screen.visibleFrame.width - 32)
        let size = hosting.sizeThatFits(in: NSSize(width: maxWidth, height: 200))
        let width = min(max(size.width, 120), maxWidth)
        let height = max(size.height, 36)

        let topInset = screen.safeAreaInsets.top
        let x = screen.frame.midX - width / 2
        let y: CGFloat = if topInset > 20 {
            screen.frame.maxY - topInset - height - 6
        } else {
            screen.frame.maxY - NSStatusBar.system.thickness - height - 10
        }

        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    private func dismissAnimated() {
        guard let panel else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduceMotion {
            panel.orderOut(nil)
            panel.alphaValue = 0
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }
}
