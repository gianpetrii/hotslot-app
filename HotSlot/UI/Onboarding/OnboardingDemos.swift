import AppKit
import KeyboardShortcuts
import SwiftUI

enum OnboardingDemoKind {
    case panel
    case slot
    case history
    case drag
    case automation
}

// MARK: - Contenedor común

struct OnboardingDemoChrome<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    }
            }
    }
}

// MARK: - Página 1: layout del panel

struct OnboardingPanelDemo: View {
    var body: some View {
        OnboardingDemoChrome {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("HotSlot")
                        .font(HotSlotTypography.rowSecondary)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    ShortcutBadge(name: .togglePanel, compact: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                }

                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 6) {
                        demoLabel("Slots")
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(height: 36)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 36)
                    }
                    .frame(width: 88)

                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 1)
                        .padding(.horizontal, 6)

                    VStack(spacing: 6) {
                        demoLabel("Historial")
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 28)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                            .frame(height: 28)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 148)
    }

    private func demoLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(HotSlotTypography.sectionTitle)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Página 2: slot (popover como el panel real)

struct OnboardingSlotDemo: View {
    @State private var isHovering = false
    @State private var isPeeking = false
    @State private var isPeekHovered = false
    @State private var peekTask: Task<Void, Never>?

    private let sampleContent = ClipContent.text(
        "Link de la reunión\nhttps://ejemplo.com/sala"
    )

    var body: some View {
        OnboardingDemoChrome {
            ZStack(alignment: .top) {
                Text("Link de la reunión\nhttps://ejemplo.com/sala")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 28)
                    .padding(8)

                HStack {
                    PanelGlyphButton(
                        systemImage: "xmark",
                        help: "Vaciar",
                        size: HotSlotDesign.slotOverlayControlSize,
                        iconSize: HotSlotDesign.slotOverlayIconSize,
                        cornerRadius: HotSlotDesign.slotOverlayCornerRadius,
                        action: {}
                    )
                    .opacity(isHovering ? 1 : 0)
                    .allowsHitTesting(isHovering)
                    Spacer()
                    ShortcutBadge(name: .pasteSlot1, compact: true)
                }
                .padding(6)
            }
            .frame(width: 148, height: 96)
            .background {
                RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(isHovering ? 0.07 : 0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(isHovering ? 0.35 : 0.2), lineWidth: 0.5)
                    }
            }
            .onHover { hovering in
                isHovering = hovering
                schedulePeek(hovering: hovering)
            }
            .popover(isPresented: $isPeeking, arrowEdge: .trailing) {
                SlotPeekView(content: sampleContent)
                    .onHover { hovering in
                        isPeekHovered = hovering
                        schedulePeek(hovering: isHovering || hovering)
                    }
            }
        }
        .frame(height: 120)
    }

    private func schedulePeek(hovering: Bool) {
        peekTask?.cancel()
        guard hovering else {
            peekTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(HotSlotDesign.slotPeekHideDelay * 1_000_000_000))
                guard !Task.isCancelled, !isHovering, !isPeekHovered else { return }
                isPeeking = false
            }
            return
        }
        peekTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(HotSlotDesign.hoverExpandDelay * 1_000_000_000))
            guard !Task.isCancelled, isHovering || isPeekHovered else { return }
            isPeeking = true
        }
    }
}

// MARK: - Página 3: historial (HistoryListView del panel)

struct OnboardingHistoryDemo: View {
    @State private var historyStore = HistoryStore.preview(items: OnboardingSamples.historyItems)
    @State private var keyboardHighlightIndex: Int?

    private var historyColumnWidth: CGFloat {
        HotSlotDesign.panelWidth - HotSlotDesign.slotsColumnWidth - 1
    }

    var body: some View {
        HistoryListView(
            historyStore: historyStore,
            items: historyStore.items,
            isSearching: false,
            onPaste: { _ in },
            keyboardHighlightIndex: $keyboardHighlightIndex,
            isDemo: true
        )
        .frame(width: historyColumnWidth)
        .frame(maxHeight: HotSlotDesign.panelBodyHeight - 24)
    }
}

// MARK: - Página 4: arrastrar

struct OnboardingDragDemo: View {
    @State private var highlightTarget = false

    var body: some View {
        OnboardingDemoChrome {
            VStack(spacing: 14) {
                dragRow(
                    from: miniHistoryRow("Clip del historial"),
                    arrow: "arrow.down.right",
                    to: miniSlot(label: "Slot 2"),
                    caption: "Arrastrá del historial a un slot"
                )

                dragRow(
                    from: miniSlot(label: "Slot 1"),
                    arrow: "arrow.left.arrow.right",
                    to: miniSlot(label: "Slot 3", highlighted: highlightTarget),
                    caption: "Arrastrá un slot sobre otro para intercambiar"
                )

                HStack(spacing: 4) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 11, weight: .medium))
                    Text("Mantené apretado y arrastrá")
                        .font(HotSlotTypography.rowSecondary)
                }
                .foregroundStyle(.tertiary)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                highlightTarget = true
            }
        }
    }

    private func dragRow<From: View, To: View>(
        from: From,
        arrow: String,
        to: To,
        caption: String
    ) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                from
                Image(systemName: arrow)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                to
            }
            Text(caption)
                .font(HotSlotTypography.rowSecondary)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private func miniHistoryRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .lineLimit(2)
            .frame(width: 108, alignment: .leading)
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            }
    }

    private func miniSlot(label: String, highlighted: Bool = false) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .frame(width: 72, height: 44)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(highlighted ? 0.14 : 0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(highlighted ? 0.5 : 0.25), lineWidth: 1)
                    }
            }
    }
}

// MARK: - Datos de ejemplo

enum OnboardingSamples {
    static var historyItems: [ClipItem] {
        _ = demoImageFileName
        return [
            ClipItem(
                content: .text(
                    """
                    Reunión con el equipo — notas copiadas del portapapeles:

                    • Revisar el hover del historial y que las imágenes mantengan proporción al expandirse.
                    • Probar pegado con Automatización activa en Safari y Mail.
                    • Link de la sala: https://ejemplo.com/sala/abc123?utm=demo

                    Pasá el mouse sobre esta fila para ver el texto completo, igual que en el panel.
                    """
                ),
                sourceAppName: "Safari"
            ),
            ClipItem(
                content: .image(fileName: demoImageFileName),
                sourceAppName: "Captura de pantalla"
            ),
            ClipItem(
                content: .text("Ítem fijado con pin"),
                sourceAppName: "Mail",
                isPinned: true
            ),
        ]
    }

    /// Copia el PNG embebido al almacén de imágenes (mismo flujo que clips reales).
    static var demoImageFileName: String {
        let fileName = "onboarding-demo.png"
        let destination = AppSupportDirectory.images.appendingPathComponent(fileName)
        guard !FileManager.default.fileExists(atPath: destination.path),
              let bundled = Bundle.main.url(forResource: "onboarding-demo", withExtension: "png") else {
            return fileName
        }
        try? FileManager.default.createDirectory(
            at: AppSupportDirectory.images,
            withIntermediateDirectories: true
        )
        try? FileManager.default.copyItem(at: bundled, to: destination)
        return fileName
    }
}

@ViewBuilder
func onboardingDemo(for kind: OnboardingDemoKind) -> some View {
    switch kind {
    case .panel: OnboardingPanelDemo()
    case .slot: OnboardingSlotDemo()
    case .history: OnboardingHistoryDemo()
    case .drag: OnboardingDragDemo()
    case .automation: EmptyView()
    }
}
