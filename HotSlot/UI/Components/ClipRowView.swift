import SwiftUI

enum ClipRowLayout {
    case standard
    case panelHandoff(isFirst: Bool)
}

struct ClipRowView: View {
    let item: ClipItem
    var layout: ClipRowLayout = .standard
    var isKeyboardHighlighted: Bool = false
    var isDemo: Bool = false
    let onPaste: () -> Void
    let onTogglePin: () -> Void
    @State private var isHovering = false
    @State private var isExpanded = false
    @State private var expandTask: Task<Void, Never>?
    @State private var isPeeking = false
    @State private var peekTask: Task<Void, Never>?

    private let expandAnimation = Animation.spring(response: 0.32, dampingFraction: 0.92)

    var body: some View {
        switch layout {
        case .panelHandoff(let isFirst):
            panelHandoffRow(isFirst: isFirst)
        case .standard:
            standardRow
        }
    }

    private var standardRow: some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .top, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    rowBody
                    Color.clear
                        .contentShape(Rectangle())
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .modifier(ClipRowInteractionModifier(isDemo: isDemo, item: item, onPaste: onPaste))
            }

            if item.isPinned || isHovering {
                PinButton(isPinned: item.isPinned, action: onTogglePin)
                    .allowsHitTesting(!isDemo)
                    .padding(.top, 6)
                    .padding(.trailing, 4)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.82, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.82, anchor: .top).combined(with: .opacity)
                    ))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(backgroundFill)
                .overlay {
                    if isHovering || isKeyboardHighlighted {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(SlotsColor.linea, lineWidth: 1)
                    }
                }
        }
        .onHover(perform: handleStandardHover)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isKeyboardHighlighted)
        .animation(.easeOut(duration: 0.15), value: item.isPinned)
        .onDisappear(perform: resetHoverState)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Clic para pegar. Arrastrá para guardar en un slot.")
    }

    private func panelHandoffRow(isFirst: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .center, spacing: 12) {
                panelHandoffBody
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(ClipRowInteractionModifier(isDemo: isDemo, item: item, onPaste: onPaste))
            }

            if isHovering || item.isPinned {
                Button(action: onTogglePin) {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(item.isPinned ? SlotsColor.naranja : SlotsColor.textoSecundario)
                        .frame(width: 26, height: 26)
                        .background {
                            Circle()
                                .fill(Color.white.opacity(0.92))
                                .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
                        }
                }
                .buttonStyle(.plain)
                .help(item.isPinned ? "Desfijar" : "Fijar arriba")
                .allowsHitTesting(!isDemo)
                .padding(.top, 4)
                .padding(.trailing, 2)
                .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .padding(.horizontal, SlotsSpace.m)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(panelHandoffBackground(isFirst: isFirst))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isKeyboardHighlighted
                        ? SlotsColor.naranja.opacity(0.5)
                        : (isHovering ? SlotsColor.linea : (isFirst ? Color(slotsHex: 0x462D14).opacity(0.08) : Color.clear)),
                    lineWidth: isKeyboardHighlighted ? 1.5 : 1
                )
        }
        .onHover { hovering in
            isHovering = hovering
            schedulePanelHandoffHover(hovering: hovering)
        }
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .animation(.easeOut(duration: 0.14), value: item.isPinned)
        .animation(expandAnimation, value: isExpanded)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isKeyboardHighlighted)
        .onDisappear(perform: resetHoverState)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Clic para pegar. Arrastrá para guardar en un slot.")
    }

    @ViewBuilder
    private var panelHandoffBody: some View {
        switch item.content {
        case .image(let fileName):
            if isExpanded {
                ClipThumbnailView(fileName: fileName, style: .row, isExpanded: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: HotSlotDesign.imageRowPreviewMaxExpandedHeight)
            } else {
                HStack(spacing: 12) {
                    ClipThumbnailView(fileName: fileName, style: .row, isExpanded: false)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        if !isExpanded {
                            Text(item.handoffPanelMetaLine())
                                .font(SlotsFont.etiqueta)
                                .foregroundStyle(SlotsColor.textoSecundario)
                                .lineLimit(1)
                        }
                        Text(item.handoffPanelPrimaryLine())
                            .font(SlotsFont.textoUI)
                            .foregroundStyle(SlotsColor.tinta)
                            .lineLimit(isExpanded ? 6 : 4)
                    }
                    .padding(.trailing, 28)
                }
            }
        case .text:
            VStack(alignment: .leading, spacing: 3) {
                if !isExpanded {
                    Text(item.handoffPanelMetaLine())
                        .font(SlotsFont.etiqueta)
                        .foregroundStyle(SlotsColor.textoSecundario)
                        .lineLimit(1)
                }
                Text(item.handoffPanelPrimaryLine())
                    .font(SlotsFont.textoUI)
                    .foregroundStyle(SlotsColor.tinta)
                    .lineLimit(isExpanded ? 10 : 4)
                    .padding(.trailing, isHovering || item.isPinned ? 28 : 0)
            }
        }
    }

    private func schedulePanelHandoffHover(hovering: Bool) {
        expandTask?.cancel()
        peekTask?.cancel()
        guard hovering else {
            withAnimation(expandAnimation) { isExpanded = false }
            isPeeking = false
            return
        }
        if case .text = item.content {
            expandTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(HotSlotDesign.hoverExpandDelay * 1_000_000_000))
                guard !Task.isCancelled, isHovering else { return }
                withAnimation(expandAnimation) { isExpanded = true }
            }
        }
        if case .image = item.content {
            expandTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(HotSlotDesign.hoverExpandDelay * 1_000_000_000))
                guard !Task.isCancelled, isHovering else { return }
                withAnimation(expandAnimation) { isExpanded = true }
            }
        }
    }

    private func resetHoverState() {
        expandTask?.cancel()
        peekTask?.cancel()
        isExpanded = false
        isPeeking = false
        isHovering = false
    }

    private func panelHandoffBackground(isFirst: Bool) -> Color {
        if isKeyboardHighlighted { return Color.white.opacity(0.95) }
        if isFirst { return Color.white.opacity(0.92) }
        if isHovering { return Color.white.opacity(0.72) }
        return Color.white.opacity(0.55)
    }

    @ViewBuilder
    private var rowBody: some View {
        VStack(alignment: .leading, spacing: 5) {
            switch item.content {
            case .image(let fileName):
                ClipThumbnailView(fileName: fileName, style: .row, isExpanded: isExpanded)
            case .text(let string):
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                Text(trimmed)
                    .font(SlotsFont.textoUI)
                    .foregroundStyle(SlotsColor.tinta)
                    .lineLimit(isExpanded ? 12 : 4)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(
                        height: textUsesExpand ? textPreviewHeight : nil,
                        alignment: .topLeading
                    )
                    .clipped()
            }

            Text(item.metadataLine())
                .font(SlotsFont.etiqueta)
                .foregroundStyle(SlotsColor.textoSecundario)
                .lineLimit(1)
                .opacity(isExpanded ? 0 : 1)
                .frame(height: isExpanded ? 0 : nil)
                .clipped()
        }
    }

    private func handleStandardHover(_ hovering: Bool) {
        isHovering = hovering
        expandTask?.cancel()
        if hovering {
            expandTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(HotSlotDesign.hoverExpandDelay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                withAnimation(expandAnimation) {
                    isExpanded = true
                }
            }
        } else {
            withAnimation(expandAnimation) {
                isExpanded = false
            }
        }
    }

    private var textUsesExpand: Bool {
        guard case .text(let string) = item.content else { return false }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 120 || trimmed.contains("\n")
    }

    private var textPreviewHeight: CGFloat {
        isExpanded ? HotSlotDesign.textRowPreviewHeightExpanded : HotSlotDesign.textRowPreviewHeight
    }

    private var backgroundFill: Color {
        if isKeyboardHighlighted { return SlotsColor.naranja.opacity(0.12) }
        if item.isPinned { return SlotsColor.teclaFondo }
        if isHovering { return Color.white.opacity(0.92) }
        return SlotsColor.papel.opacity(0.5)
    }
}

private struct ClipRowInteractionModifier: ViewModifier {
    let isDemo: Bool
    let item: ClipItem
    let onPaste: () -> Void

    func body(content: Content) -> some View {
        if isDemo {
            content
        } else {
            content
                .onTapGesture(perform: onPaste)
                .draggable(PanelDragPayload.historyItem(id: item.id)) {
                    Text(item.content.previewText)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                        .padding(8)
                        .frame(maxWidth: 180, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
        }
    }
}

private struct PinButton: View {
    let isPinned: Bool
    let action: () -> Void

    var body: some View {
        PanelGlyphButton(
            systemImage: isPinned ? "pin.fill" : "pin",
            foreground: isPinned ? Color.accentColor : .secondary,
            help: isPinned ? "Desfijar" : "Fijar arriba",
            action: action
        )
    }
}
