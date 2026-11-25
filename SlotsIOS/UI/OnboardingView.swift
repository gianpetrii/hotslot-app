import SwiftUI

/// Recorrido de bienvenida. Mismo criterio que el del Mac (tres pantallas: qué es, el permiso, cómo abrirlo rápido),
/// adaptado al iPhone: acá el «permiso» es el aviso de pegar de iOS y los «atajos» son los gestos del sistema.
struct OnboardingView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var showGuide = false
    @State private var pasteTried = false

    private let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                switch page {
                case 0: slotsPage
                case 1: permissionPage
                default: quickOpenPage
                }
            }
            .id(page)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(reduceMotion ? .opacity : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            footer
        }
        .padding(.horizontal, SlotsSpace.m)
        .background(SlotsColor.papel.ignoresSafeArea())
        .sheet(isPresented: $showGuide) { SettingsSheet() }
    }

    // MARK: - Marco

    private var header: some View {
        HStack {
            Button { onFinished() } label: {
                Text("Saltar")
                    .slotsText(15)
                    .foregroundStyle(SlotsColor.textoSecundario)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(SlotsColor.botonSecundario, in: Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.top, SlotsSpace.s)
    }

    private var footer: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? SlotsColor.tinta.opacity(0.55) : SlotsColor.tinta.opacity(0.15))
                        .frame(width: index == page ? 18 : 7, height: 7)
                }
            }
            .accessibilityHidden(true)

            HStack(spacing: SlotsSpace.s) {
                if page > 0 {
                    Button { go(page - 1) } label: {
                        Text("Atrás")
                            .slotsText(17)
                            .foregroundStyle(SlotsColor.tinta)
                            .padding(.horizontal, 24)
                            .frame(height: 64)
                            .background(SlotsColor.botonSecundario, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                SheetPrimaryButton(title: page == pageCount - 1 ? "Empezar" : "Siguiente") {
                    if page == pageCount - 1 { onFinished() } else { go(page + 1) }
                }
            }
        }
        .padding(.bottom, SlotsSpace.m)
    }

    private func go(_ target: Int) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.4, dampingFraction: 0.85)) { page = target }
    }

    // MARK: - Páginas

    private func pageText(title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: SlotsSpace.s) {
            Text(title)
                .slotsText(40, tracking: -0.04, lineHeight: 1)
                .foregroundStyle(SlotsColor.tinta)
                .accessibilityAddTraits(.isHeader)
            Text(caption)
                .slotsText(16, medium: false, lineHeight: 1.4)
                .foregroundStyle(SlotsColor.textoTerciario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var slotsPage: some View {
        VStack(alignment: .leading, spacing: SlotsSpace.l) {
            Spacer(minLength: 0)
            OnboardingSlotsDemo()
            pageText(
                title: "Tus slots",
                caption: "Guardá links, textos, imágenes o archivos en un slot y copialos con un toque, sin escribirlos de nuevo."
            )
            Spacer(minLength: 0)
        }
    }

    private var permissionPage: some View {
        VStack(alignment: .leading, spacing: SlotsSpace.m) {
            Spacer(minLength: 0)
            pageText(
                title: "Un permiso y listo",
                caption: "Cuando pegás algo que copiaste en otra app, iOS pregunta si lo permitís. Elegí «Permitir» una vez en Ajustes y no vuelve a preguntar."
            )
            VStack(alignment: .leading, spacing: SlotsSpace.s) {
                step(1, "Copiá cualquier texto y tocá «Probar pegado». iOS muestra su aviso.") {
                    actionPill(pasteTried ? "Listo, ya probé" : "Probar pegado", icon: "doc.on.clipboard") { tryPaste() }
                }
                step(2, "Abrí Ajustes de Slots, tocá «Pegar desde otras apps» y elegí «Permitir».") {
                    actionPill("Abrir Ajustes", icon: "gearshape") { openSettings() }
                }
            }
            Text("Slots solo lee el portapapeles cuando vos tocás un botón para pegar.")
                .slotsText(13, medium: false)
                .foregroundStyle(SlotsColor.textoSecundario)
            Spacer(minLength: 0)
        }
    }

    private var quickOpenPage: some View {
        VStack(alignment: .leading, spacing: SlotsSpace.m) {
            Spacer(minLength: 0)
            pageText(
                title: "Abrí Slots más rápido",
                caption: "iPhone no permite gestos propios, pero podés usar los de iOS para copiar un slot sin abrir la app."
            )
            VStack(spacing: SlotsSpace.s) {
                quickRow("hand.tap", "Tocar atrás", "Doble o triple toque en la tapa")
                quickRow("button.horizontal.top.press", "Botón de Acción", "En los iPhone que lo tienen")
                quickRow("switch.2", "Centro de Control", "Y botones de la pantalla de bloqueo")
                quickRow("square.grid.2x2", "Widgets", "Tocá un slot para copiarlo")
            }
            actionPill("Ver cómo configurarlo", icon: "questionmark.circle") { showGuide = true }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Piezas

    private func step<Content: View>(_ number: Int, _ text: String, @ViewBuilder action: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(number)")
                    .slotsText(12)
                    .foregroundStyle(SlotsColor.tinta)
                    .frame(width: 22, height: 22)
                    .background(SlotsColor.botonSecundario, in: Circle())
                Text(text)
                    .slotsText(15, medium: false, lineHeight: 1.35)
                    .foregroundStyle(SlotsColor.tinta)
            }
            action().padding(.leading, 32)
        }
    }

    private func actionPill(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14, weight: .medium))
                Text(title).slotsText(15)
            }
            .foregroundStyle(SlotsColor.tinta)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(.white, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func quickRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(SlotsColor.tinta, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title).slotsText(16).foregroundStyle(SlotsColor.tinta)
                Text(detail).slotsText(13, medium: false).foregroundStyle(SlotsColor.textoSecundario)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Acciones

    /// Lee el texto del portapapeles una vez: es lo que hace aparecer el aviso de iOS y la fila en Ajustes.
    private func tryPaste() {
        let pasteboard = UIPasteboard.general
        if pasteboard.hasStrings { _ = pasteboard.string }
        pasteTried = true
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// Mini grilla de ejemplo: una card se «copia» sola cada tanto, como pasa al tocar un slot.
private struct OnboardingSlotsDemo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copied = 0

    private let items: [(title: String, detail: String, background: Color?, dark: Bool)] = [
        ("Mi portfolio", "Link\nbehance.net", nil, false),
        ("Gracias por escribir", "Texto\n8 palabras", SlotsColor.cardOscura, true),
        ("Naranja de marca", "Color\n#E2501D", SlotsColor.naranja, true),
        ("Contrato.pdf", "Archivo\nPDF · 212 KB", nil, false),
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                let isCopied = copied == index
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Text(item.detail)
                            .slotsText(11, lineHeight: 1.2)
                            .foregroundStyle(item.dark ? .white.opacity(0.72) : SlotsColor.textoSecundario)
                        Spacer(minLength: 4)
                        if isCopied {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(item.dark ? SlotsColor.naranja : .white)
                                .frame(width: 22, height: 22)
                                .background(item.dark ? Color.white : SlotsColor.naranja, in: Circle())
                        }
                    }
                    Spacer(minLength: 4)
                    Text(isCopied ? "Copiado" : item.title)
                        .slotsText(20, tracking: -0.03, lineHeight: 0.95)
                        .foregroundStyle(item.dark ? .white : SlotsColor.tinta)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .padding(12)
                .frame(height: 112)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(item.background ?? .white, in: RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous))
                .scaleEffect(isCopied && !reduceMotion ? 0.97 : 1)
            }
        }
        .accessibilityHidden(true)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1600))
                withAnimation(.easeOut(duration: 0.2)) { copied = (copied + 1) % items.count }
            }
        }
    }
}
