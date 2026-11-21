import AuthenticationServices
import SwiftUI

/// Tarjeta de inicio de sesión (diseño de Dante, `05-flujos/cuenta`): 440 de ancho, radio 28, botones de 52.
struct AccountCardView: View {
    @Bindable var model: AccountFlowModel
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch model.screen {
            case .options: options
            case .email: emailForm
            case .reset: resetForm
            case .resetSent: resetSent
            case .done: done
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
                AppleSignInButton { model.signInWithApple() }
                    .frame(height: 52)
                    .clipShape(Capsule())

                Button { model.signInWithGoogle() } label: {
                    HStack(spacing: 10) {
                        GoogleMark()
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
                .buttonStyle(TutorialPressStyle(scale: 0.97))

                Button { model.go(.email) } label: {
                    Text("Continuar con email")
                        .font(SettingsStyle.medium(16))
                        .foregroundStyle(SlotsColor.tinta)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule(style: .continuous).fill(SlotsColor.teclaFondo))
                        .contentShape(Capsule())
                }
                .buttonStyle(TutorialPressStyle(scale: 0.97))
            }
            .padding(.top, 4)

            errorLine

            Button("Ahora no") { model.onFinish() }
                .buttonStyle(.plain)
                .font(SettingsStyle.medium(14))
                .foregroundStyle(SlotsColor.tinta)
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
            .buttonStyle(.plain)
            .font(SettingsStyle.medium(13))
            .foregroundStyle(SlotsColor.textoSecundario)
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

    // MARK: Piezas

    private var backButton: some View {
        Button { model.back() } label: {
            Text("‹")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(SlotsColor.tinta)
                .frame(width: 36, height: 36)
                .background(Circle().fill(SlotsColor.teclaFondo))
        }
        .buttonStyle(.plain)
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
        .buttonStyle(TutorialPressStyle(scale: 0.97))
    }

    private func field(_ placeholder: String, text: Binding<String>, secure: Bool, focus target: Field) -> some View {
        Group {
            if secure {
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
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(focus == target ? Color.white : SettingsStyle.campo))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(focus == target ? SlotsColor.naranja : SettingsStyle.borde, lineWidth: focus == target ? 2 : 1)
        )
    }

    private func submitFromKeyboard() {
        if model.screen == .reset { model.sendReset() } else { model.submitEmail() }
    }
}

/// Botón oficial «Continuar con Apple» (estilo negro), con el mismo alto y forma de píldora del diseño.
struct AppleSignInButton: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .continue, style: .black)
        button.cornerRadius = 26
        button.target = context.coordinator
        button.action = #selector(Coordinator.tapped)
        return button
    }

    func updateNSView(_ nsView: ASAuthorizationAppleIDButton, context: Context) {
        context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}

/// Marca «G» de Google. Para publicar conviene reemplazarla por el recurso oficial de la guía de marca de Google.
private struct GoogleMark: View {
    var body: some View {
        Text("G")
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(slotsHex: 0x4285F4), Color(slotsHex: 0x34A853), Color(slotsHex: 0xFBBC05), Color(slotsHex: 0xEA4335)],
                    startPoint: .topTrailing, endPoint: .bottomLeading
                )
            )
    }
}
