import SwiftUI

// MARK: - Medición de elementos

struct TutorialFramesKey: PreferenceKey {
    static var defaultValue: [TutorialTarget: Anchor<CGRect>] = [:]

    static func reduce(value: inout [TutorialTarget: Anchor<CGRect>], nextValue: () -> [TutorialTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func tutorialTarget(_ target: TutorialTarget) -> some View {
        anchorPreference(key: TutorialFramesKey.self, value: .bounds) { [target: $0] }
    }
}

// MARK: - Logo

/// Marca de Slots: un rectángulo alto y dos cuadrados, el de abajo naranja.
struct SlotsLogoMark: View {
    var height: CGFloat = 120

    var body: some View {
        let stroke = height * 0.055
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: height * 0.1, style: .continuous)
                .strokeBorder(SlotsColor.tinta, lineWidth: stroke)
                .frame(width: height * 0.43, height: height)
            RoundedRectangle(cornerRadius: height * 0.1, style: .continuous)
                .strokeBorder(SlotsColor.tinta, lineWidth: stroke)
                .frame(width: height * 0.5, height: height * 0.44)
                .offset(x: height * 0.5)
            RoundedRectangle(cornerRadius: height * 0.09, style: .continuous)
                .fill(SlotsColor.naranja)
                .frame(width: height * 0.44, height: height * 0.43)
                .offset(x: height * 0.53, y: height * 0.55)
        }
        .frame(width: height * 1.0, height: height, alignment: .topLeading)
    }
}

// MARK: - Texto con teclas

/// Tecla dentro del texto: 26 de alto, fondo #F1EDE8.
struct TutorialKeyCap: View {
    let symbol: String

    var body: some View {
        Text(symbol)
            .font(SettingsStyle.medium(13))
            .foregroundStyle(SlotsColor.tinta)
            .padding(.horizontal, 7)
            .frame(minWidth: 26, minHeight: 26)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(SlotsColor.teclaFondo)
                    .shadow(color: SlotsColor.tinta.opacity(0.12), radius: 0, y: 1.5)
            )
    }
}

/// Párrafo que mezcla palabras y teclas, con salto de línea automático.
struct TutorialRichText: View {
    let tokens: [TutorialToken]
    var fontSize: CGFloat = 14

    var body: some View {
        TutorialWrapLayout(spacing: 4, lineSpacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                switch item {
                case .word(let word):
                    Text(word)
                        .font(SettingsStyle.regular(fontSize))
                        .foregroundStyle(SlotsColor.textoTerciario)
                        .frame(minHeight: 26)
                case .keys(let symbols):
                    HStack(spacing: 3) {
                        ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                            TutorialKeyCap(symbol: symbol)
                        }
                    }
                }
            }
        }
    }

    private enum Item {
        case word(String)
        case keys([String])
    }

    private var items: [Item] {
        var result: [Item] = []
        for token in tokens {
            switch token {
            case .text(let text):
                let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
                // El punto o la coma que sigue a una tecla se pega a la palabra anterior.
                result.append(contentsOf: words.map { Item.word($0) })
            case .keys(let keys):
                result.append(.keys(keys.map { String($0) }))
            }
        }
        return result
    }
}

struct TutorialWrapLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                widest = max(widest, x - spacing)
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        widest = max(widest, x - spacing)
        return CGSize(width: proposal.width ?? widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y + (lineHeight == 0 ? 0 : 0)), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Datos de muestra (solo en memoria)

private struct SampleSlot {
    enum Look { case flyer, paper, dark }
    let index: Int
    let kind: String
    let title: String
    let look: Look
    let shortcut: String
}

private let sampleSlots: [Int: SampleSlot] = [
    1: SampleSlot(index: 1, kind: "Imagen", title: "Flyer\nExpo", look: .flyer, shortcut: "⌘⇧A"),
    2: SampleSlot(index: 2, kind: "meet.google.com", title: "Link de la reunión", look: .paper, shortcut: "⌘⇧S"),
    3: SampleSlot(index: 3, kind: "Texto", title: "Respuesta presupuesto", look: .paper, shortcut: "⌘⇧D"),
    4: SampleSlot(index: 4, kind: "Color", title: "#E2501D", look: .dark, shortcut: "⌘⇧Q"),
    5: SampleSlot(index: 5, kind: "Texto", title: "Gracias por escribir", look: .paper, shortcut: "⌘⇧W"),
]

private struct SampleHistoryRow: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

private let sampleHistory: [SampleHistoryRow] = [
    SampleHistoryRow(title: "meet.google.com/abc-defg-hij", detail: "Link · hace 2 min"),
    SampleHistoryRow(title: "Hola Lucía, te paso el presupuesto con los cambios que hablamos.", detail: "Texto · hace 9 min"),
    SampleHistoryRow(title: "#E2501D", detail: "Color · hace 21 min"),
    SampleHistoryRow(title: "Gracias por escribir, te respondo en el día.", detail: "Texto · hace 1 h"),
    SampleHistoryRow(title: "flyer-expo-2026.png", detail: "Imagen · hace 3 h"),
    SampleHistoryRow(title: "Av. Santa Fe 3253, Palermo", detail: "Texto · ayer"),
]

// MARK: - Panel de muestra

/// Réplica estática del panel con slots de ejemplo. No lee ni escribe nada del usuario.
struct TutorialMockPanel: View {
    var body: some View {
        PanelChrome {
            VStack(spacing: HotSlotDesign.panelSectionGap) {
                header
                HStack(alignment: .top, spacing: HotSlotDesign.panelBodyGap) {
                    grid
                        .padding(.top, HotSlotDesign.panelColumnTopInset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    history
                        .padding(.top, HotSlotDesign.panelColumnTopInset)
                        .frame(width: HotSlotDesign.historyColumnWidth)
                }
                .padding(.horizontal, HotSlotDesign.horizontalPadding)
                .frame(maxHeight: .infinity)
                libraryBar
            }
            .padding(.bottom, SlotsSpace.xl)
            .frame(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelHeight, alignment: .top)
        }
    }

    // MARK: Cabecera

    private var header: some View {
        HStack(alignment: .center, spacing: SlotsSpace.l) {
            Text("Trabajo")
                .font(SlotsFont.tituloPantalla(false))
                .foregroundStyle(SlotsColor.tinta)
                .lineLimit(1)
                .tutorialTarget(.title)
                .frame(maxWidth: .infinity, minHeight: SlotsRadius.controlAlto, alignment: .leading)

            HStack(spacing: SlotsSpace.s) {
                searchField.tutorialTarget(.search)
                circleButton("slider.horizontal.3", iconSize: 18).tutorialTarget(.settingsButton)
                circleButton("xmark", iconSize: 14)
            }
        }
        .padding(.horizontal, HotSlotDesign.horizontalPadding)
        .padding(.top, SlotsSpace.xl)
    }

    private var searchField: some View {
        HStack(spacing: SlotsSpace.s) {
            ZStack {
                Circle().fill(Color.white.opacity(0.9)).frame(width: 32, height: 32)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SlotsColor.tinta)
            }
            Text("Buscar en slots e historial")
                .font(SlotsFont.textoUI)
                .foregroundStyle(SlotsColor.textoSecundario)
            Spacer(minLength: 0)
            Text("⌘F")
                .font(SlotsFont.etiqueta)
                .foregroundStyle(SlotsColor.textoSecundario)
                .padding(.horizontal, SlotsSpace.s)
                .padding(.vertical, SlotsSpace.xs)
                .background(Capsule(style: .continuous).fill(Color.black.opacity(0.06)))
        }
        .padding(.horizontal, SlotsSpace.s)
        .frame(width: HotSlotDesign.panelSearchFieldWidth, height: SlotsRadius.controlAlto)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.6))
                .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
        )
    }

    private func circleButton(_ symbol: String, iconSize: CGFloat) -> some View {
        Image(systemName: symbol)
            .font(.system(size: iconSize, weight: .medium))
            .foregroundStyle(SlotsColor.tinta)
            .frame(width: SlotsRadius.controlAlto, height: SlotsRadius.controlAlto)
            .background(Circle().fill(Color.black.opacity(0.07)))
    }

    // MARK: Grilla

    private var grid: some View {
        GeometryReader { geo in
            let gap = SlotsSpace.entreCards
            let columnWidth = (geo.size.width - gap * 2) / 3
            let rowHeight = (geo.size.height - gap) / 2
            HStack(spacing: gap) {
                card(1).frame(width: columnWidth, height: rowHeight * 2 + gap).tutorialTarget(.slot1)
                VStack(spacing: gap) {
                    HStack(spacing: gap) {
                        card(2).frame(width: columnWidth, height: rowHeight).tutorialTarget(.slot2)
                        card(3).frame(width: columnWidth, height: rowHeight)
                    }
                    HStack(spacing: gap) {
                        card(4).frame(width: columnWidth, height: rowHeight)
                        card(5).frame(width: columnWidth, height: rowHeight)
                    }
                }
            }
        }
        .tutorialTarget(.grid)
    }

    private func card(_ index: Int) -> some View {
        MockSlotCard(slot: sampleSlots[index]!)
    }

    // MARK: Historial

    private var history: some View {
        VStack(alignment: .leading, spacing: SlotsSpace.s) {
            HStack {
                Text("Historial")
                    .font(SlotsFont.tituloHistorial)
                    .foregroundStyle(SlotsColor.tinta)
                Spacer()
                Text("Arrastrá a un slot")
                    .font(SlotsFont.etiqueta)
                    .foregroundStyle(SlotsColor.textoSecundario)
            }
            .padding(.bottom, 4)
            ForEach(sampleHistory) { row in
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(SettingsStyle.medium(14))
                        .foregroundStyle(SlotsColor.tinta)
                        .lineLimit(2)
                    Text(row.detail)
                        .font(SettingsStyle.regular(12))
                        .foregroundStyle(SlotsColor.textoSecundario)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous).fill(Color.white.opacity(0.75)))
            }
            Spacer(minLength: 0)
        }
        .tutorialTarget(.history)
    }

    // MARK: Bibliotecas

    private var libraryBar: some View {
        HStack(spacing: SlotsSpace.m) {
            HStack(spacing: SlotsSpace.s) {
                LibraryPillLabel(name: "Trabajo", count: 5, isActive: true)
                LibraryPillLabel(name: "Música", count: 4, isActive: false)
                LibraryPillLabel(name: "Personal", count: 3, isActive: false)
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(SlotsColor.tinta)
                    .frame(width: SlotsRadius.controlAlto, height: SlotsRadius.controlAlto)
                    .background(Circle().fill(Color.white.opacity(0.85)))
            }
            .tutorialTarget(.pills)
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                Text("Guardar portapapeles")
                    .font(SlotsFont.textoUI)
                    .foregroundStyle(.white)
                    .padding(.leading, 20)
                    .padding(.trailing, 14)
                Text("›")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.12)))
                    .padding(.trailing, 6)
            }
            .frame(height: SlotsRadius.controlAlto)
            .background(Capsule(style: .continuous).fill(SlotsColor.cardOscura))
            .tutorialTarget(.saveButton)
        }
        .padding(.horizontal, HotSlotDesign.horizontalPadding)
    }

}

/// Muestra del menú de clic derecho: es el menú real, dibujado a mano.
struct TutorialContextMenu: View {
    private let items: [(String, Bool)] = [
        ("Renombrar…", false),
        ("Color de fondo", true),
        ("Reemplazar con el portapapeles", false),
        ("Mover a…", true),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack {
                    Text(item.0)
                    Spacer(minLength: 8)
                    if item.1 { Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)) }
                }
                .font(SettingsStyle.regular(13))
                .foregroundStyle(index == 0 ? Color.white : SlotsColor.tinta)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(index == 0 ? SlotsColor.naranja : Color.clear))
            }
            Rectangle().fill(SlotsColor.tinta.opacity(0.1)).frame(height: 1).padding(.vertical, 4)
            HStack {
                Text("Vaciar slot")
                Spacer()
            }
            .font(SettingsStyle.regular(13))
            .foregroundStyle(SlotsColor.tinta)
            .padding(.horizontal, 10)
            .frame(height: 28)
        }
        .padding(6)
        .frame(width: 236)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(slotsHex: 0xFAF8F5, opacity: 0.96))
                .shadow(color: Color(slotsHex: 0x28190A, opacity: 0.26), radius: 18, y: 14)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(SlotsColor.tinta.opacity(0.18), lineWidth: 0.5))
        )
    }
}

// MARK: - Card de muestra

private struct MockSlotCard: View {
    let slot: SampleSlot

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Slot \(slot.index)")
                        Text(slot.kind)
                    }
                    .font(SlotsFont.etiqueta)
                    .foregroundStyle(secondary)
                    Spacer(minLength: 8)
                    Text(slot.shortcut)
                        .font(SettingsStyle.medium(11))
                        .foregroundStyle(slot.look == .paper ? SlotsColor.tinta : SlotsColor.tinta)
                        .padding(.horizontal, 8)
                        .frame(height: HotSlotDesign.slotHeaderChipHeight)
                        .background(Capsule(style: .continuous).fill(slot.look == .paper ? SlotsColor.arena.opacity(0.7) : Color.white.opacity(0.9)))
                }
                if slot.look == .flyer {
                    VStack(alignment: .leading, spacing: 4) {
                        Spacer(minLength: 0)
                        Text("EXPO DISEÑO 26").font(SettingsStyle.medium(12)).foregroundStyle(.white.opacity(0.85))
                        Text("14—16\nNOV").font(SettingsStyle.medium(34)).tracking(-1.2).foregroundStyle(.white)
                        Text("PALERMO, CABA\n18 A 22 H\nENTRADA LIBRE").font(SettingsStyle.regular(11)).foregroundStyle(.white.opacity(0.85))
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 8)
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    Text(slot.title)
                        .font(SlotsFont.tituloCard)
                        .tracking(-0.9)
                        .foregroundStyle(primary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if slot.look == .dark {
                        Circle().fill(SlotsColor.naranja).frame(width: 34, height: 34)
                    }
                }
            }
            .padding(SlotsSpace.m)
        }
        .clipShape(RoundedRectangle(cornerRadius: HotSlotDesign.cardCornerRadius, style: .continuous))
    }

    private var primary: Color { slot.look == .paper ? SlotsColor.tinta : .white }
    private var secondary: Color { slot.look == .paper ? SlotsColor.textoSecundario : .white.opacity(0.85) }

    @ViewBuilder private var background: some View {
        switch slot.look {
        case .paper:
            Color.white
        case .dark:
            SlotsColor.cardOscura
        case .flyer:
            LinearGradient(
                stops: [
                    .init(color: Color(slotsHex: 0xF4ECE4), location: 0),
                    .init(color: Color(slotsHex: 0xE9915A), location: 0.38),
                    .init(color: Color(slotsHex: 0xB5461F), location: 0.68),
                    .init(color: Color(slotsHex: 0x2A1414), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
    }
}
