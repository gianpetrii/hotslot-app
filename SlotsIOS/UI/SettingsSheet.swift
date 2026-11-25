import SwiftUI

/// Ajustes mínimo: guía para abrir Slots rápido, estado de iCloud y versión.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("confirmLibraryDelete") private var confirmLibraryDelete = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return "Slots \(short) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SlotsSpace.l) {
                SheetHeader(title: "Ajustes") { dismiss() }

                VStack(alignment: .leading, spacing: SlotsSpace.s) {
                    Text("Abrir Slots más rápido")
                        .slotsText(24, tracking: -0.02, lineHeight: 1.1)
                        .foregroundStyle(SlotsColor.tinta)
                    Text("iPhone no permite gestos propios, pero podés usar los de iOS.")
                        .slotsText(15, medium: false, lineHeight: 1.4)
                        .foregroundStyle(SlotsColor.textoTerciario)
                }

                guide(
                    icon: "hand.tap",
                    title: "Tocar atrás",
                    steps: [
                        "Abrí Ajustes › Accesibilidad › Tocar › Tocar atrás.",
                        "Elegí «Doble toque» o «Triple toque».",
                        "En la lista de Atajos, elegí «Abrir Slots» o «Copiar slot».",
                    ]
                )
                guide(
                    icon: "button.horizontal.top.press",
                    title: "Botón de Acción",
                    steps: [
                        "Abrí Ajustes › Botón de acción.",
                        "Deslizá hasta «Control» (o «Atajo») y tocá «Elegir».",
                        "Buscá «Abrir Slots» o «Copiar slot». Solo iPhones que tienen el botón.",
                    ]
                )
                guide(
                    icon: "switch.2",
                    title: "Centro de Control y pantalla de bloqueo",
                    steps: [
                        "Mantené presionado un lugar libre del Centro de Control y tocá «Agregar un control».",
                        "Elegí los controles de Slots. «Copiar slot» te deja elegir qué slot.",
                        "En la pantalla de bloqueo: mantenela presionada › Personalizar › los botones de abajo.",
                    ]
                )
                guide(
                    icon: "square.grid.2x2",
                    title: "Widgets",
                    steps: [
                        "Mantené presionada la pantalla de inicio › «+» › Slots.",
                        "Tocá el widget para elegir la biblioteca. Tocar un slot lo copia sin abrir la app.",
                    ]
                )

                Button {
                    hasCompletedOnboarding = false
                    dismiss()
                } label: {
                    Label("Ver la bienvenida otra vez", systemImage: "play.circle")
                        .slotsText(15)
                        .foregroundStyle(SlotsColor.tinta)
                }
                .buttonStyle(.plain)

                Toggle(isOn: $confirmLibraryDelete) {
                    Text("Confirmar antes de eliminar una biblioteca")
                        .slotsText(15)
                        .foregroundStyle(SlotsColor.tinta)
                }
                .tint(SlotsColor.naranja)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tus slots se sincronizan por iCloud con tus otros dispositivos.")
                        .slotsText(13, medium: false)
                        .foregroundStyle(SlotsColor.textoSecundario)
                    Text(version)
                        .slotsText(13, medium: false)
                        .foregroundStyle(SlotsColor.textoSecundario)
                }
                .padding(.top, SlotsSpace.s)
            }
            .padding(.horizontal, SlotsSpace.m)
            .padding(.top, 28)
            .padding(.bottom, SlotsSpace.xl)
        }
        .scrollIndicators(.hidden)
        .slotsSheetStyle()
    }

    private func guide(icon: String, title: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(SlotsColor.tinta, in: Circle())
                Text(title).slotsText(17).foregroundStyle(SlotsColor.tinta)
            }
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .slotsText(12)
                        .foregroundStyle(SlotsColor.tinta)
                        .frame(width: 22, height: 22)
                        .background(SlotsColor.botonSecundario, in: Circle())
                    Text(step)
                        .slotsText(15, medium: false, lineHeight: 1.35)
                        .foregroundStyle(SlotsColor.textoTerciario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(SlotsSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous))
    }
}
