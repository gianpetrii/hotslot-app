import SwiftUI

/// Tarjeta de inicio de sesión (diseño de Dante, `05-flujos/cuenta`): 440 de ancho, radio 28, botones de 52.
struct AccountCardView: View {
    @Bindable var model: AccountFlowModel
    @FocusState private var focus: Field?
    @State private var hoveredField: Field?

    private enum Field { case email, password }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch model.screen {
            case .options: options
            case .email: emailForm
            case .reset: resetForm
            case .resetSent: resetSent
            case .done: done
            case .confirmDelete: confirmDelete
            }
        }
        .id(model.screen)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(x: 16)),
            removal: .opacity
        ))
        .padding(EdgeInsets(top: 32, leading: 28, bottom: 24, trailing: 28))
        .frame(width: 440)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color(slotsHex: 0x28190A, opacity: 0.30), radius: 40, y: 30)
        )
        .overlay(alignment: .topLeading) {
            if model.screen == .email || model.screen == .reset || model.screen == .resetSent {
                backButton.padding(20)
            }
        }
        .animation(.easeOut(duration: 0.25), value: model.screen)
        .disabled(model.isBusy)
        .opacity(model.isBusy ? 0.8 : 1)
    }

    // MARK: 1 · Opciones

    private var options: some View {
        Group {
            SlotsLogoMark(height: 40)
            if model.isFirstRun { eyebrow("Último paso · opcional") }
            title("Creá tu cuenta de Slots")
            bodyText("Así vas a poder guardar tu licencia en tu cuenta y, cuando llegue la sincronización, tener tus slots también en el iPhone.")

            VStack(spacing: 8) {
                Button { model.signInWithApple() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .offset(y: -1)
                        Text("Continuar con Apple")
                            .font(SettingsStyle.medium(16))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule(style: .continuous).fill(Color.black))
                    .contentShape(Capsule())
                }
                .buttonStyle(TutorialPressStyle(scale: 0.95))
                .modifier(PillHover())

                Button { model.signInWithGoogle() } label: {
                    HStack(spacing: 10) {
                        Image("GoogleG")
                            .resizable()
                            .frame(width: 18, height: 18)
                        Text("Continuar con Google")
                            .font(SettingsStyle.medium(16))
                            .foregroundStyle(SlotsColor.tinta)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule(style: .continuous).fill(Color.white))
                    .overlay(Capsule(style: .continuous).strokeBorder(Color(slotsHex: 0xE0DAD3), lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(TutorialPressStyle(scale: 0.95))
                .modifier(PillHover())

                Button { model.go(.email) } label: {
                    Text("Continuar con email")
                        .font(SettingsStyle.medium(16))
                        .foregroundStyle(SlotsColor.tinta)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule(style: .continuous).fill(SlotsColor.teclaFondo))
                        .contentShape(Capsule())
                }
                .buttonStyle(TutorialPressStyle(scale: 0.95))
                .modifier(PillHover())
            }
            .padding(.top, 4)

            errorLine

            Button("Ahora no") { model.onFinish() }
                .buttonStyle(TextLinkPressStyle())
                .font(SettingsStyle.medium(14))
                .foregroundStyle(SlotsColor.tinta)
                .modifier(TextHover())
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

            Text("Al continuar aceptás la [Política de privacidad](https://hotslot-app-docs.vercel.app/privacy.html).")
                .font(SettingsStyle.regular(12))
                .foregroundStyle(SlotsColor.textoSecundario)
                .tint(SlotsColor.textoSecundario)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: 2 · Email y contraseña

    private var emailForm: some View {
        Group {
            Spacer().frame(height: 28)
            eyebrow("Continuar con email")
            title(model.mode == .signUp ? "Creá tu cuenta" : "Entrá a tu cuenta")
            bodyText(model.mode == .signUp
                ? "Elegí una contraseña de al menos 6 caracteres."
                : "Escribí el email y la contraseña con los que te registraste.")

            field("Email", text: $model.email, secure: false, focus: .email)
                .padding(.top, 4)
            field("Contraseña", text: $model.password, secure: true, focus: .password)

            errorLine

            primaryButton(model.mode == .signUp ? "Crear cuenta" : "Entrar") { model.submitEmail() }

            HStack {
                Button(model.mode == .signUp ? "¿Ya tenés cuenta? Entrá" : "¿No tenés cuenta? Creá una") {
                    model.mode = model.mode == .signUp ? .signIn : .signUp
                    model.errorMessage = nil
                }
                Spacer()
                if model.mode == .signIn {
                    Button("Olvidé mi contraseña") { model.go(.reset) }
                }
            }
            .buttonStyle(TextLinkPressStyle())
            .font(SettingsStyle.medium(13))
            .foregroundStyle(SlotsColor.textoSecundario)
            .modifier(TextHover())
            // El fondo del clic suma 12 pt a cada lado: se compensa para que el texto quede alineado con los campos.
            .padding(.horizontal, -12)
            .padding(.top, 2)
        }
        .onAppear { focus = .email }
    }

    // MARK: Restablecer contraseña

    private var resetForm: some View {
        Group {
            Spacer().frame(height: 28)
            eyebrow("Restablecer contraseña")
            title("¿Cuál es tu email?")
            bodyText("Te mandamos un mail para que elijas una contraseña nueva.")
            field("Email", text: $model.email, secure: false, focus: .email)
                .padding(.top, 4)
            errorLine
            primaryButton("Enviarme el mail") { model.sendReset() }
        }
        .onAppear { focus = .email }
    }

    private var resetSent: some View {
        Group {
            Spacer().frame(height: 28)
            title("Revisá tu mail")
            bodyText("Mandamos un mail a \(model.email.trimmingCharacters(in: .whitespacesAndNewlines)). Abrí el link para elegir una contraseña nueva. Si no te llega, fijate en spam.")
            primaryButton("Volver a entrar") { model.mode = .signIn; model.go(.email) }
                .padding(.top, 4)
        }
    }

    // MARK: 4 · Listo

    private var done: some View {
        Group {
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(SlotsColor.tinta))
            title(model.mode == .signUp && model.account.profile?.provider == .email ? "Listo, ya tenés cuenta" : "Listo, ya estás adentro")

            if let profile = model.account.profile {
                HStack(spacing: 12) {
                    Text(profile.initial)
                        .font(SettingsStyle.semibold(16))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(SlotsColor.naranja))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(profile.email ?? "Cuenta de Slots")
                            .font(SettingsStyle.medium(15))
                            .foregroundStyle(SlotsColor.tinta)
                            .lineLimit(1)
                        Text("Conectada con \(profile.provider.title)")
                            .font(SettingsStyle.regular(13))
                            .foregroundStyle(SlotsColor.textoSecundario)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SlotsColor.teclaFondo))
            }

            bodyText("Podés cerrar sesión o eliminar tu cuenta cuando quieras desde Ajustes › Cuenta.")
            primaryButton(model.isFirstRun ? "Empezar a usar Slots" : "Listo") { model.onFinish() }
                .padding(.top, 4)
        }
    }

    // MARK: Eliminar cuenta: confirmar contraseña

    private var confirmDelete: some View {
        Group {
            eyebrow("Eliminar cuenta")
            title("Confirmá tu contraseña")
            bodyText("Por seguridad, escribí tu contraseña para eliminar tu cuenta. No se puede deshacer y tus slots en esta Mac no se tocan.")
            field("Contraseña", text: $model.password, secure: true, focus: .password)
                .padding(.top, 4)
            errorLine
            Button { model.confirmDelete() } label: {
                Text("Eliminar cuenta")
                    .font(SettingsStyle.medium(16))
                    .foregroundStyle(SlotsColor.oxido)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule(style: .continuous).fill(SlotsColor.teclaFondo))
                    .contentShape(Capsule())
            }
            .buttonStyle(TutorialPressStyle(scale: 0.95))
            .modifier(PillHover())
            primaryButton("Cancelar") { model.back() }
        }
        .onAppear { focus = .password }
    }

    // MARK: Piezas

    private var backButton: some View {
        Button { model.back() } label: {
            Text("‹")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(SlotsColor.tinta)
                .frame(width: 36, height: 36)
                .background(Circle().fill(SlotsColor.teclaFondo))
        }
        .buttonStyle(TutorialPressStyle(scale: 0.92))
        .modifier(PillHover())
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(SettingsStyle.medium(12))
            .foregroundStyle(SlotsColor.textoSecundario)
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(SettingsStyle.medium(30))
            .tracking(-1.05)
            .foregroundStyle(SlotsColor.tinta)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(SettingsStyle.regular(15))
            .foregroundStyle(SlotsColor.textoTerciario)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var errorLine: some View {
        if let message = model.errorMessage {
            Text(message)
                .font(SettingsStyle.regular(13))
                .foregroundStyle(SlotsColor.oxido)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(SettingsStyle.medium(16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule(style: .continuous).fill(SlotsColor.tinta))
                .contentShape(Capsule())
        }
        .buttonStyle(TutorialPressStyle(scale: 0.95))
        .modifier(PillHover())
    }

    private func field(_ placeholder: String, text: Binding<String>, secure: Bool, focus target: Field) -> some View {
        Group {
            if secure && !model.showPassword {
                SecureField("", text: text, prompt: Text(placeholder).foregroundStyle(SlotsColor.textoSecundario.opacity(0.6)))
            } else {
                TextField("", text: text, prompt: Text(placeholder).foregroundStyle(SlotsColor.textoSecundario.opacity(0.6)))
            }
        }
        .textFieldStyle(.plain)
        .font(SettingsStyle.regular(16))
        .foregroundStyle(SlotsColor.tinta)
        .focused($focus, equals: target)
        .onSubmit { target == .email && model.screen == .email ? (focus = .password) : submitFromKeyboard() }
        .padding(.leading, 16)
        .padding(.trailing, secure ? 6 : 16)
        .frame(height: 52)
        .overlay(alignment: .trailing) {
            if secure {
                Button {
                    model.showPassword.toggle()
                    focus = target
                } label: {
                    Image(systemName: model.showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(SlotsColor.textoSecundario)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(TutorialPressStyle(scale: 0.88))
                .padding(.trailing, 6)
                .help(model.showPassword ? "Ocultar contraseña" : "Mostrar contraseña")
            }
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(focus == target ? Color.white : SettingsStyle.campo))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    focus == target ? SlotsColor.naranja : (hoveredField == target ? Color(slotsHex: 0xCFC8C0) : SettingsStyle.borde),
                    lineWidth: focus == target ? 2 : 1
                )
        )
        .onHover { hoveredField = $0 ? target : (hoveredField == target ? nil : hoveredField) }
        .animation(.easeOut(duration: 0.14), value: focus)
        .animation(.easeOut(duration: 0.14), value: hoveredField)
    }

    private func submitFromKeyboard() {
        switch model.screen {
        case .reset: model.sendReset()
        case .confirmDelete: model.confirmDelete()
        default: model.submitEmail()
        }
    }
}

/// Clic en un texto: aparece una pastilla de fondo y se achica, así se nota aunque no tenga forma de botón.
private struct TextLinkPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(SlotsColor.tinta.opacity(configuration.isPressed ? 0.12 : 0)))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(
                configuration.isPressed ? .easeOut(duration: 0.07) : .spring(response: 0.3, dampingFraction: 0.6),
                value: configuration.isPressed
            )
            .contentShape(Capsule())
    }
}

/// Al pasar el mouse: solo la sombra cálida del resto de la app (sin zoom).
private struct PillHover: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .slotsHoverLift(hovering, scales: false)
            .onHover { hovering = $0 }
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: hovering)
    }
}

/// Texto que se aclara al pasar el mouse.
private struct TextHover: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .opacity(hovering ? 1 : 0.75)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.14), value: hovering)
    }
}
