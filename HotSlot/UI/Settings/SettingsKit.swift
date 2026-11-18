import SwiftUI

/// Componentes de la ventana de Ajustes (handoff de Dante, `05-flujos/ajustes`).
/// Todas las pestañas se arman con estas piezas: no se inventan estilos por pestaña.
enum SettingsStyle {
    static let separador = Color(slotsHex: 0xEEEAE5)
    static let borde = Color(slotsHex: 0xE6E1DB)
    static let campo = Color(slotsHex: 0xF6F3EF)
    static let apagado = Color(slotsHex: 0xDCD6CF)
    static let chevron = Color(slotsHex: 0x8C8781)
    static let opciones = Color(slotsHex: 0xF1EDE8)

    static func medium(_ size: CGFloat) -> Font { .custom("InterTight-Medium", size: size) }
    static func regular(_ size: CGFloat) -> Font { .custom("InterTight-Regular", size: size) }
    static func semibold(_ size: CGFloat) -> Font { .custom("InterTight-SemiBold", size: size) }
}

/// Título de pestaña: 64 / 500, tracking -0.04em.
struct SettingsTabTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(SettingsStyle.medium(64))
            .tracking(-2.56)
            .foregroundStyle(SlotsColor.tinta)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(height: 64 * 0.92, alignment: .leading)
            .padding(.bottom, 18)
    }
}

/// Título de sección: 13 / 500, #5E5A56.
struct SettingsSection<Content: View>: View {
    let title: String?
    @ViewBuilder var content: () -> Content

    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(SettingsStyle.medium(13))
                    .foregroundStyle(SlotsColor.textoSecundario)
                    .padding(.horizontal, 4)
            }
            content()
        }
    }
}

/// Card blanca con filas separadas por una línea de 1 pt.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content()) { subviews in
                ForEach(subviews.indices, id: \.self) { index in
                    subviews[index]
                    if index < subviews.count - 1 {
                        Rectangle()
                            .fill(SettingsStyle.separador)
                            .frame(height: 1)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white)
        )
    }
}

/// Fila: título (y descripción opcional) a la izquierda, control a la derecha.
struct SettingsRow<Control: View>: View {
    let title: String
    var detail: String?
    var destructive = false
    var disabled = false
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(SettingsStyle.medium(17))
                    .tracking(-0.17)
                    .foregroundStyle(destructive ? SlotsColor.oxido : SlotsColor.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(SettingsStyle.regular(13))
                        .lineSpacing(1.4)
                        .foregroundStyle(SlotsColor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 24)
            control()
        }
        .padding(.vertical, 14)
        .opacity(disabled ? 0.4 : 1)
        .allowsHitTesting(!disabled)
    }
}

/// Fila de solo texto (sin control).
struct SettingsTextRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(SettingsStyle.medium(17))
            .tracking(-0.17)
            .foregroundStyle(SlotsColor.textoSecundario)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
    }
}

/// Nota informativa, fuera de las cards.
struct SettingsNote: View {
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "info")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(SlotsColor.tinta))
            Text(text)
                .font(SettingsStyle.regular(13))
                .foregroundStyle(SlotsColor.textoTerciario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.5))
        )
    }
}

/// Interruptor de 46 × 28.
struct SettingsSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(isOn ? SlotsColor.naranja : SettingsStyle.apagado)
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .shadow(color: SlotsColor.tinta.opacity(0.25), radius: 1.5, y: 1)
                    .padding(2)
            }
            .frame(width: 46, height: 28)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isOn ? "Activado" : "Desactivado")
    }
}

/// Opciones (2 o 3) en un control segmentado.
struct SettingsOptions<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let active = option.value == selection
                Button {
                    withAnimation(.easeOut(duration: 0.14)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(SettingsStyle.medium(14))
                        .foregroundStyle(active ? SlotsColor.tinta : SlotsColor.textoSecundario)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background {
                            if active {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color.white)
                                    .shadow(color: SlotsColor.tinta.opacity(0.12), radius: 1, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(SettingsStyle.opciones))
    }
}

/// Selector con menú nativo (más de 3 opciones).
struct SettingsPicker<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value

    var body: some View {
        Menu {
            ForEach(options.indices, id: \.self) { index in
                Button(options[index].title) { selection = options[index].value }
            }
        } label: {
            HStack(spacing: 8) {
                Text(options.first { $0.value == selection }?.title ?? "")
                    .font(SettingsStyle.medium(15))
                    .foregroundStyle(SlotsColor.tinta)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SlotsColor.textoSecundario)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(SettingsStyle.campo))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(SettingsStyle.borde, lineWidth: 1))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

/// Campo de texto de 40 de alto.
struct SettingsTextField: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat = 260

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(SlotsColor.textoSecundario.opacity(0.6)))
            .textFieldStyle(.plain)
            .font(SettingsStyle.regular(15))
            .foregroundStyle(SlotsColor.tinta)
            .padding(.horizontal, 14)
            .frame(width: width, height: 40)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SettingsStyle.campo))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(SettingsStyle.borde, lineWidth: 1))
    }
}

/// Botón en forma de pill de 36 de alto.
struct SettingsPillButton: View {
    enum Kind { case secondary, primary }

    let title: String
    var kind: Kind = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SettingsStyle.medium(14))
                .foregroundStyle(kind == .primary ? Color.white : SlotsColor.tinta)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(Capsule(style: .continuous).fill(kind == .primary ? SlotsColor.tinta : SettingsStyle.opciones))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Estado de un permiso: chip de 28 de alto.
struct SettingsPermissionChip: View {
    let granted: Bool
    var action: (() -> Void)?

    var body: some View {
        if granted {
            HStack(spacing: 6) {
                Circle().fill(SlotsColor.naranja).frame(width: 6, height: 6)
                Text("Concedido")
                    .font(SettingsStyle.medium(14))
                    .foregroundStyle(SlotsColor.tinta)
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Capsule(style: .continuous).fill(SettingsStyle.opciones))
        } else {
            Button { action?() } label: {
                Text("Dar permiso")
                    .font(SettingsStyle.medium(14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 28)
                    .background(Capsule(style: .continuous).fill(SlotsColor.tinta))
            }
            .buttonStyle(.plain)
        }
    }
}

/// Valor de solo lectura a la derecha de una fila.
struct SettingsValue: View {
    let text: String

    var body: some View {
        Text(text)
            .font(SettingsStyle.regular(15))
            .foregroundStyle(SlotsColor.textoSecundario)
    }
}

/// Menos / valor / más, con el aspecto de «Opciones».
struct SettingsStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus") { value = max(range.lowerBound, value - step) }
            Text("\(value)")
                .font(SettingsStyle.medium(14))
                .foregroundStyle(SlotsColor.tinta)
                .frame(minWidth: 44)
                .monospacedDigit()
            stepButton("plus") { value = min(range.upperBound, value + step) }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(SettingsStyle.opciones))
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SlotsColor.tinta)
                .frame(width: 34, height: 30)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
