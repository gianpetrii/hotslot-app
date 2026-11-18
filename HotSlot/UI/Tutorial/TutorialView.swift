import SwiftUI

/// Capa a pantalla completa del tutorial: bienvenida, pop-up, recorrido de 8 pasos y cierre.
/// Medidas y tiempos del handoff de Dante (`05-flujos/tutorial`).
struct TutorialView: View {
    @Bindable var model: TutorialModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false
    @State private var pulse = false
    @State private var balloonSize: CGSize = CGSize(width: 320, height: 200)
    @State private var panelFrames: [TutorialTarget: CGRect] = [:]

    private let panelSize = CGSize(width: HotSlotDesign.panelWidth, height: HotSlotDesign.panelHeight)

    var body: some View {
        GeometryReader { geo in
            let origin = panelOrigin(in: geo.size)
            ZStack(alignment: .topLeading) {
                if isWelcome {
                    welcome(origin: origin)
                        .transition(.opacity)
                }
                if !isWelcome {
                    tourLayers(origin: origin, screen: geo.size)
                        .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.98)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: isWelcome)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard model.phase == .welcome else { return }
                withAnimation(.easeOut(duration: 0.45)) { model.phase = .popup }
            }
        }
    }

    private var isWelcome: Bool { model.phase == .welcome || model.phase == .popup }

    /// El panel de muestra ocupa el mismo lugar que el panel real.
    private func panelOrigin(in screen: CGSize) -> CGPoint {
        CGPoint(
            x: (screen.width - panelSize.width) / 2,
            y: (screen.height - HotSlotDesign.panelWindowHeight) / 2
        )
    }

    // MARK: - Bienvenida y pop-up

    private func welcome(origin: CGPoint) -> some View {
        let popup = model.phase == .popup
        return ZStack(alignment: .topLeading) {
            PanelChrome { Color.clear }
                .frame(width: panelSize.width, height: panelSize.height)
                .offset(x: origin.x, y: origin.y)

            VStack(spacing: 22) {
                HStack(spacing: 22) {
                    SlotsLogoMark(height: 120)
                    Text("Slots")
                        .font(.custom("InterTight-Medium", size: 96))
                        .tracking(-4.8)
                        .foregroundStyle(SlotsColor.tinta)
                }
                Text("Bienvenido")
                    .font(SettingsStyle.medium(28))
                    .foregroundStyle(SlotsColor.textoTerciario)
                    .opacity(popup ? 0 : 1)
            }
            .scaleEffect(popup ? 0.62 : 1)
            .offset(y: popup ? -212 : 0)
            .frame(width: panelSize.width, height: panelSize.height)
            .offset(x: origin.x, y: origin.y)
            .animation(.easeOut(duration: 0.45), value: popup)

            if popup {
                popupCard
                    .frame(width: panelSize.width, height: panelSize.height)
                    .offset(x: origin.x, y: origin.y + 54)
                    .transition(.opacity.combined(with: .offset(y: 12)).combined(with: .scale(scale: 0.97)))
            }
        }
    }

    private var popupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Primera vez en Slots")
                .font(SettingsStyle.medium(12))
                .foregroundStyle(SlotsColor.textoSecundario)
            Text("¿Te mostramos cómo funciona?")
                .font(SettingsStyle.medium(30))
                .tracking(-1.05)
                .foregroundStyle(SlotsColor.tinta)
                .fixedSize(horizontal: false, vertical: true)
            Text("Un recorrido de 8 pasos con slots de ejemplo. Al terminar los sacamos y tu panel queda vacío para empezar.")
                .font(SettingsStyle.regular(15))
                .foregroundStyle(SlotsColor.textoTerciario)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                Button { model.startTour() } label: {
                    HStack(spacing: 8) {
                        Text("Recorrido rápido")
                            .font(SettingsStyle.medium(16))
                            .foregroundStyle(.white)
                        Spacer()
                        keyBadge("↩", dark: true)
                        Text("›")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(SlotsColor.naranja))
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 7)
                    .frame(height: 52)
                    .background(Capsule(style: .continuous).fill(SlotsColor.tinta))
                    .contentShape(Capsule())
                }
                .buttonStyle(TutorialPressStyle(scale: 0.97))

                Button { model.close() } label: {
                    HStack {
                        Text("Manos a la obra")
                            .font(SettingsStyle.medium(16))
                            .foregroundStyle(SlotsColor.tinta)
                        Spacer()
                        keyBadge("Esc", dark: false)
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 14)
                    .frame(height: 52)
                    .background(Capsule(style: .continuous).fill(SlotsColor.teclaFondo))
                    .contentShape(Capsule())
                }
                .buttonStyle(TutorialPressStyle(scale: 0.97))
            }
            .padding(.top, 4)

            Text("Podés verlo cuando quieras desde Ajustes › General.")
                .font(SettingsStyle.regular(12))
                .foregroundStyle(SlotsColor.textoSecundario)
                .frame(maxWidth: .infinity)
        }
        .padding(28)
        .frame(width: 440)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color(slotsHex: 0x28190A, opacity: 0.28), radius: 40, y: 30)
        )
    }

    private func keyBadge(_ text: String, dark: Bool) -> some View {
        Text(text)
            .font(SettingsStyle.medium(12))
            .foregroundStyle(dark ? Color.white : SlotsColor.textoSecundario)
            .padding(.horizontal, 8)
            .frame(minWidth: 30, minHeight: 24)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(dark ? Color.white.opacity(0.14) : Color.black.opacity(0.07))
            )
    }

    // MARK: - Recorrido

    @ViewBuilder
    private func tourLayers(origin: CGPoint, screen: CGSize) -> some View {
        let step = currentStep
        let hole = holeRect(origin: origin, step: step)

        ZStack(alignment: .topLeading) {
            // Fondo desenfocado: el panel de muestra entero.
            mock(origin: origin)
                .blur(radius: 10)
                .saturation(0.85)
            Color(slotsHex: 0x1C140E, opacity: 0.30)

            if let step, let hole {
                // Nítido solo dentro del hueco.
                mock(origin: origin)
                    .mask { holeMask(hole, radius: step.holeRadius) }

                focusRing(hole, radius: step.holeRadius)

                if step.showsContextMenu, let slot = absolute(.slot2, origin: origin) {
                    TutorialContextMenu()
                        .offset(x: slot.minX + 24, y: slot.minY + 54)
                        .allowsHitTesting(false)
                }

                balloon(step: step, hole: hole, screen: screen)
                    .id(model.phase)
                    .transition(.opacity)
            }

            if model.phase == .closing {
                closingCard
                    .frame(width: screen.width, height: screen.height)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            examplesNotice(origin: origin)
        }
        .animation(.easeInOut(duration: 0.3), value: model.phase)
    }

    private var currentStep: TutorialStep? {
        if case .step(let index) = model.phase { return model.steps[index] }
        return nil
    }

    private func mock(origin: CGPoint) -> some View {
        TutorialMockPanel()
            .frame(width: panelSize.width, height: panelSize.height)
            .offset(x: origin.x, y: origin.y)
            .backgroundPreferenceValue(TutorialFramesKey.self) { anchors in
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { publishFrames(anchors, proxy: proxy) }
                        .onChange(of: proxy.size) { _, _ in publishFrames(anchors, proxy: proxy) }
                }
            }
            .allowsHitTesting(false)
    }

    private func publishFrames(_ anchors: [TutorialTarget: Anchor<CGRect>], proxy: GeometryProxy) {
        var result: [TutorialTarget: CGRect] = [:]
        for (target, anchor) in anchors { result[target] = proxy[anchor] }
        if panelFrames != result {
            DispatchQueue.main.async { panelFrames = result }
        }
    }

    /// Marco en pantalla de un elemento. Los marcos medidos ya vienen en coordenadas de pantalla
    /// (el panel de muestra se dibuja desplazado dentro de la capa).
    private func absolute(_ target: TutorialTarget, origin: CGPoint) -> CGRect? {
        // Los slots están dentro de un GeometryReader (no publican marco): salen de la grilla, con la misma cuenta del panel.
        if target == .slot1 || target == .slot2, let grid = panelFrames[.grid] {
            let gap = SlotsSpace.entreCards
            let column = (grid.width - gap * 2) / 3
            let row = (grid.height - gap) / 2
            return target == .slot1
                ? CGRect(x: grid.minX, y: grid.minY, width: column, height: row * 2 + gap)
                : CGRect(x: grid.minX + column + gap, y: grid.minY, width: column, height: row)
        }
        return panelFrames[target]
    }

    private func holeRect(origin: CGPoint, step: TutorialStep?) -> CGRect? {
        guard let step, let frame = absolute(step.target, origin: origin) else { return nil }
        return frame.insetBy(dx: -8, dy: -8)
    }

    private func holeMask(_ hole: CGRect, radius: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .frame(width: hole.width, height: hole.height)
                .offset(x: hole.minX, y: hole.minY)
        }
    }

    private func focusRing(_ hole: CGRect, radius: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius + 3, style: .continuous)
                .strokeBorder(SlotsColor.naranja.opacity(pulse ? 0.12 : 0.30), lineWidth: pulse ? 12 : 7)
                .padding(-(pulse ? 12 : 7))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.white, lineWidth: 2)
        }
        .frame(width: hole.width, height: hole.height)
        .offset(x: hole.minX, y: hole.minY)
        .allowsHitTesting(false)
    }

    /// «Slots de ejemplo · se borran al terminar», siempre por encima del desenfoque.
    private func examplesNotice(origin: CGPoint) -> some View {
        let title = absolute(.title, origin: origin) ?? .zero
        return HStack(spacing: 8) {
            Circle().fill(SlotsColor.naranja).frame(width: 8, height: 8)
            Text("Slots de ejemplo · se borran al terminar")
                .font(SettingsStyle.medium(13))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Capsule(style: .continuous).fill(SlotsColor.tinta))
        .fixedSize()
        .offset(x: title.maxX + 24, y: title.midY - 15)
        .allowsHitTesting(false)
    }

    // MARK: Globo

    private func balloon(step: TutorialStep, hole: CGRect, screen: CGSize) -> some View {
        let gap: CGFloat = 16
        let size = balloonSize
        let side = resolvedSide(step.side, hole: hole, size: size, screen: screen, gap: gap)

        var x: CGFloat
        var y: CGFloat
        switch side {
        case .right: x = hole.maxX + gap; y = hole.midY - size.height / 2
        case .left: x = hole.minX - gap - size.width; y = hole.midY - size.height / 2
        case .below: x = hole.midX - size.width / 2; y = hole.maxY + gap
        case .above: x = hole.midX - size.width / 2; y = hole.minY - gap - size.height
        }
        x = min(max(x, 16), screen.width - size.width - 16)
        y = min(max(y, 16), screen.height - size.height - 16)

        return balloonCard(step: step)
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { balloonSize = $0 }
            .background(alignment: .topLeading) {
                arrow(side: side, hole: hole, x: x, y: y, size: size)
            }
            .offset(x: x, y: y)
    }

    private func resolvedSide(_ side: TutorialBalloonSide, hole: CGRect, size: CGSize, screen: CGSize, gap: CGFloat) -> TutorialBalloonSide {
        switch side {
        case .right where hole.maxX + gap + size.width > screen.width - 16: return .left
        case .left where hole.minX - gap - size.width < 16: return .right
        case .below where hole.maxY + gap + size.height > screen.height - 16: return .above
        case .above where hole.minY - gap - size.height < 16: return .below
        default: return side
        }
    }

    private func arrow(side: TutorialBalloonSide, hole: CGRect, x: CGFloat, y: CGFloat, size: CGSize) -> some View {
        let square = RoundedRectangle(cornerRadius: 2, style: .continuous).fill(Color.white).frame(width: 14, height: 14).rotationEffect(.degrees(45))
        let horizontalCenter = min(max(hole.midX - x, 28), size.width - 28)
        let verticalCenter = min(max(hole.midY - y, 28), size.height - 28)
        return ZStack(alignment: .topLeading) {
            switch side {
            case .right: square.offset(x: -7, y: verticalCenter - 7)
            case .left: square.offset(x: size.width - 7, y: verticalCenter - 7)
            case .below: square.offset(x: horizontalCenter - 7, y: -7)
            case .above: square.offset(x: horizontalCenter - 7, y: size.height - 7)
            }
        }
    }

    private func balloonCard(step: TutorialStep) -> some View {
        let index = stepIndex
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(index + 1) de \(model.stepCount)")
                    .font(SettingsStyle.medium(12))
                    .foregroundStyle(SlotsColor.textoSecundario)
                Spacer()
                HStack(spacing: 5) {
                    ForEach(0..<model.stepCount, id: \.self) { dot in
                        Capsule(style: .continuous)
                            .fill(dot == index ? SlotsColor.naranja : Color(slotsHex: 0xE2DED8))
                            .frame(width: dot == index ? 18 : 6, height: 6)
                    }
                }
            }
            Text(step.title)
                .font(SettingsStyle.medium(20))
                .tracking(-0.4)
                .foregroundStyle(SlotsColor.tinta)
            TutorialRichText(tokens: step.text)
            HStack {
                Button("Saltar tutorial") { model.close() }
                    .buttonStyle(.plain)
                    .font(SettingsStyle.regular(13))
                    .foregroundStyle(SlotsColor.textoSecundario)
                Spacer()
                Button { model.next() } label: {
                    Text("Siguiente")
                        .font(SettingsStyle.medium(14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 40)
                        .background(Capsule(style: .continuous).fill(SlotsColor.tinta))
                        .contentShape(Capsule())
                }
                .buttonStyle(TutorialPressStyle(scale: 0.93))
            }
            .padding(.top, 6)
        }
        .padding(20)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color(slotsHex: 0x28190A, opacity: 0.28), radius: 30, y: 24)
        )
    }

    private var stepIndex: Int {
        if case .step(let index) = model.phase { return index }
        return 0
    }

    // MARK: Cierre

    private var closingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(SlotsColor.tinta))
            Text("Todo listo")
                .font(SettingsStyle.medium(26))
                .tracking(-0.9)
                .foregroundStyle(SlotsColor.tinta)
            TutorialRichText(tokens: [
                .text("Sacamos los slots de ejemplo: tu panel queda vacío y listo para llenar. Cuando guardes o pegues algo, te avisamos arriba, junto al notch. Abrí el panel cuando quieras con "),
                .keys(model.togglePanelKeys),
                .text("."),
            ], fontSize: 15)
            Button { model.close() } label: {
                Text("Empezar a usar Slots")
                    .font(SettingsStyle.medium(16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Capsule(style: .continuous).fill(SlotsColor.tinta))
                    .contentShape(Capsule())
            }
            .buttonStyle(TutorialPressStyle(scale: 0.97))
            .padding(.top, 6)
        }
        .padding(28)
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color(slotsHex: 0x28190A, opacity: 0.30), radius: 35, y: 30)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Presión de un botón: se achica un poco en 120 ms.
struct TutorialPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
