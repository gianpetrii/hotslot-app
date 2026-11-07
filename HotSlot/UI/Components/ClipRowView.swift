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
    @State private var collapsedTextHeight: CGFloat = 0
    @State private var threeLineTextHeight: CGFloat = 0
    @State private var copyFlash = false
    @Environment(AppState.self) private var appState

    private static let collapsedTextLines = 2

    /// Expandir solo tiene sentido si el texto no entra en los renglones colapsados.
    private var textOverflowsCollapsed: Bool {
        threeLineTextHeight > collapsedTextHeight + 1
    }

    private let expandAnimation = Animation.spring(response: 0.32, dampingFraction: 0.92)

    private var clickHint: String {
        let action = AppSettings.load().clickItemAction == .copyToClipboard
            ? "Clic para copiar, después ⌘V para pegar."
            : "Clic para pegar."
        return "\(action) Arrastrá para guardar en un slot."
    }

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
        }
        .slotsHoverLift(isHovering)
        .onHover(perform: handleStandardHover)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isKeyboardHighlighted)
        .animation(.easeOut(duration: 0.15), value: item.isPinned)
        .onDisappear(perform: resetHoverState)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(clickHint)
    }

    private func panelHandoffRow(isFirst: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .center, spacing: 12) {
                panelHandoffBody
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(ClipRowInteractionModifier(isDemo: isDemo, item: item, onPaste: onPaste, handlesTap: false))
            }

            if isHovering || item.isPinned {
                Button(action: onTogglePin) {
                    Image(systemName: "pin")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(item.isPinned ? SlotsColor.naranja : SlotsColor.textoSecundario)
                        .frame(width: 26, height: 26)
                        .background {
                            if showsPinBackdrop {
                                Circle()
                                    .fill(Color.white.opacity(0.92))
                                    .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
                            }
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
                    isKeyboardHighlighted ? SlotsColor.naranja.opacity(0.5) : (isFirst ? Color(slotsHex: 0x462D14).opacity(0.08) : Color.clear),
                    lineWidth: isKeyboardHighlighted ? 1.5 : 1
                )
        }
        .slotsHoverLift(isHovering && !copyFlash)
        .onTapGesture {
            guard !isDemo else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { copyFlash = true }
            onPaste()
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
        .accessibilityHint(clickHint)
        .onChange(of: appState.isPanelVisible) { _, visible in
            guard visible, copyFlash else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { copyFlash = false }
        }
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
        case .file:
            HStack(spacing: 12) {
                FileClipIconView(content: item.content, side: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.handoffPanelMetaLine())
                        .font(SlotsFont.etiqueta)
                        .foregroundStyle(SlotsColor.textoSecundario)
                        .lineLimit(1)
                    Text(item.content.fileName)
                        .font(SlotsFont.textoUI)
                        .foregroundStyle(SlotsColor.tinta)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(item.content.fileDetail)
                        .font(SlotsFont.etiqueta)
                        .foregroundStyle(SlotsColor.textoSecundario)
                        .lineLimit(1)
                }
                .padding(.trailing, 28)
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
                    .lineLimit(isExpanded ? 8 : Self.collapsedTextLines)
                    .background { textOverflowProbe }
                    .padding(.trailing, isHovering || item.isPinned ? 28 : 0)
            }
        }
    }

    /// Mide el texto con el ancho real de la fila: 2 renglones contra 3.
    private var textOverflowProbe: some View {
        ZStack(alignment: .topLeading) {
            probeText(lines: Self.collapsedTextLines)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { collapsedTextHeight = $0 }
            probeText(lines: Self.collapsedTextLines + 1)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { threeLineTextHeight = $0 }
        }
        .hidden()
    }

    private func probeText(lines: Int) -> some View {
        Text(item.handoffPanelPrimaryLine())
            .font(SlotsFont.textoUI)
            .lineLimit(lines)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Solo la imagen agrandada queda debajo del pin; en el resto el ícono va sin fondo.
    private var showsPinBackdrop: Bool {
        if case .image = item.content { return isExpanded }
        return false
    }

    private func schedulePanelHandoffHover(hovering: Bool) {
        expandTask?.cancel()
        peekTask?.cancel()
        guard hovering else {
            withAnimation(expandAnimation) { isExpanded = false }
            isPeeking = false
            return
        }
        if case .text = item.content, textOverflowsCollapsed {
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
        if copyFlash { return SlotsColor.papel }
        if isKeyboardHighlighted { return Color.white.opacity(0.95) }
        if isFirst { return Color.white.opacity(0.92) }
        return Color.white.opacity(0.55)
    }

    @ViewBuilder
    private var rowBody: some View {
        VStack(alignment: .leading, spacing: 5) {
            switch item.content {
            case .image(let fileName):
                ClipThumbnailView(fileName: fileName, style: .row, isExpanded: isExpanded)
            case .file:
                HStack(spacing: 10) {
                    FileClipIconView(content: item.content, side: 32)
                    Text(item.content.fileName)
                        .font(SlotsFont.textoUI)
                        .foregroundStyle(SlotsColor.tinta)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
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
    var handlesTap: Bool = true
    @State private var copyFlash = false

    func body(content: Content) -> some View {
        if isDemo {
            content
        } else {
            let row = content
                .draggable(PanelDragPayload.historyItem(id: item.id)) {
                    Text(item.content.previewText)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                        .padding(8)
                        .frame(maxWidth: 180, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            if handlesTap {
                row
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(SlotsColor.papel)
                            .opacity(copyFlash ? 1 : 0)
                            .allowsHitTesting(false)
                    }
                    .onTapGesture {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) { copyFlash = true }
                        onPaste()
                    }
            } else {
                row
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
