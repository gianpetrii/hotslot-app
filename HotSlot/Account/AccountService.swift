import AppKit
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

/// Cuenta de Slots (Firebase Auth): Apple, Google o email con contraseña.
/// Guarda solo email, proveedor e identificador. No toca slots, historial ni licencia.
@MainActor @Observable
final class AccountService: NSObject {
    enum Provider: String {
        case apple, google, email

        var title: String {
            switch self {
            case .apple: "Apple"
            case .google: "Google"
            case .email: "email"
            }
        }
    }

    struct Profile: Equatable {
        let uid: String
        let email: String?
        let provider: Provider

        var initial: String {
            (email ?? "S").first.map { String($0).uppercased() } ?? "S"
        }
    }

    /// Mensaje corto para mostrar a la persona (nunca el error técnico).
    struct Failure: Error {
        let message: String
    }

    private(set) var profile: Profile?
    private(set) var isConfigured = false

    private var listener: AuthStateDidChangeListenerHandle?
    private var appleContinuation: CheckedContinuation<ASAuthorization, Error>?
    private var appleWindow: NSWindow?

    var isSignedIn: Bool { profile != nil }

    /// Sign in with Apple no se puede firmar en el DMG (perfil Developer ID): el botón solo aparece si la app lo trae.
    var isAppleSignInAvailable: Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        return SecTaskCopyValueForEntitlement(task, "com.apple.developer.applesignin" as CFString, nil) != nil
    }

    /// Se llama una vez al arrancar la app.
    func start() {
        guard !isConfigured else { return }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        FirebaseApp.configure()
        isConfigured = true
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.profile = user.flatMap(Self.makeProfile) }
        }
        profile = Auth.auth().currentUser.flatMap(Self.makeProfile)
    }

    private static func makeProfile(_ user: User) -> Profile {
        let id = user.providerData.first?.providerID
        let provider: Provider = switch id {
        case "apple.com": .apple
        case "google.com": .google
        default: .email
        }
        return Profile(uid: user.uid, email: user.email ?? user.providerData.first?.email, provider: provider)
    }

    // MARK: - Email

    func signUp(email: String, password: String) async throws {
        do {
            try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            throw Self.failure(from: error)
        }
    }

    func signIn(email: String, password: String) async throws {
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            throw Self.failure(from: error)
        }
    }

    func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw Self.failure(from: error)
        }
    }

    // MARK: - Google

    func signInWithGoogle(presenting window: NSWindow?) async throws {
        let credential = try await googleCredential(presenting: window)
        do {
            try await Auth.auth().signIn(with: credential)
        } catch {
            throw Self.failure(from: error)
        }
    }

    private func googleCredential(presenting window: NSWindow?) async throws -> AuthCredential {
        guard let clientID = FirebaseApp.app()?.options.clientID, let window else {
            throw Failure(message: "No se pudo abrir el inicio de sesión de Google.")
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: window)
            guard let idToken = result.user.idToken?.tokenString else {
                throw Failure(message: "Google no devolvió la identidad. Probá de nuevo.")
            }
            return GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
        } catch let error as Failure {
            throw error
        } catch {
            throw Self.failure(from: error)
        }
    }

    // MARK: - Apple

    func signInWithApple(presenting window: NSWindow?) async throws {
        let (credential, _) = try await appleCredential(presenting: window)
        do {
            try await Auth.auth().signIn(with: credential)
        } catch {
            throw Self.failure(from: error)
        }
    }

    private func appleCredential(presenting window: NSWindow?) async throws -> (AuthCredential, String?) {
        let nonce = Self.randomNonce()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email]
        request.nonce = Self.sha256(nonce)

        appleWindow = window
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        let authorization: ASAuthorization
        do {
            authorization = try await withCheckedThrowingContinuation { continuation in
                appleContinuation = continuation
                controller.performRequests()
            }
        } catch {
            throw Self.failure(from: error)
        }

        guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = apple.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw Failure(message: "Apple no devolvió la identidad. Probá de nuevo.")
        }
        let code = apple.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: nonce, fullName: nil)
        return (credential, code)
    }

    // MARK: - Cerrar sesión y eliminar

    func signOut() {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    /// Elimina la cuenta. Pide volver a identificarse (Firebase lo exige) y, con Apple, revoca el permiso.
    func deleteAccount(password: String?, presenting window: NSWindow?) async throws {
        guard let user = Auth.auth().currentUser, let profile else { return }
        do {
            switch profile.provider {
            case .apple:
                let (credential, code) = try await appleCredential(presenting: window)
                try await user.reauthenticate(with: credential)
                if let code { try await Auth.auth().revokeToken(withAuthorizationCode: code) }
            case .google:
                let credential = try await googleCredential(presenting: window)
                try await user.reauthenticate(with: credential)
            case .email:
                guard let email = profile.email, let password, !password.isEmpty else {
                    throw Failure(message: "Escribí tu contraseña para confirmar.")
                }
                try await user.reauthenticate(with: EmailAuthProvider.credential(withEmail: email, password: password))
            }
            try await user.delete()
            GIDSignIn.sharedInstance.signOut()
        } catch let error as Failure {
            throw error
        } catch {
            throw Self.failure(from: error)
        }
    }

    // MARK: - Errores

    private static func failure(from error: Error) -> Failure {
        if let apple = error as? ASAuthorizationError, apple.code == .canceled {
            return Failure(message: "")
        }
        let ns = error as NSError
        if ns.domain == kGIDSignInErrorDomain, ns.code == GIDSignInError.canceled.rawValue {
            return Failure(message: "")
        }
        guard ns.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: ns.code) else {
            return Failure(message: "No se pudo completar. Probá de nuevo.")
        }
        switch code {
        case .invalidEmail: return Failure(message: "Revisá el email.")
        case .wrongPassword, .invalidCredential, .userNotFound:
            return Failure(message: "Email o contraseña incorrectos.")
        case .emailAlreadyInUse: return Failure(message: "Ya hay una cuenta con ese email. Probá iniciar sesión.")
        case .weakPassword: return Failure(message: "La contraseña es muy corta: usá al menos 6 caracteres.")
        case .networkError: return Failure(message: "No hay conexión. Probá de nuevo en un rato.")
        case .tooManyRequests: return Failure(message: "Demasiados intentos. Esperá un momento y probá de nuevo.")
        case .requiresRecentLogin: return Failure(message: "Por seguridad, volvé a iniciar sesión y probá de nuevo.")
        default: return Failure(message: "No se pudo completar. Probá de nuevo.")
        }
    }

    // MARK: - Utilidades de Apple

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        while result.count < length {
            var byte: UInt8 = 0
            guard SecRandomCopyBytes(kSecRandomDefault, 1, &byte) == errSecSuccess else { continue }
            if byte < charset.count { result.append(charset[Int(byte)]) }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension AccountService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            appleContinuation?.resume(returning: authorization)
            appleContinuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            appleContinuation?.resume(throwing: error)
            appleContinuation = nil
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated { appleWindow ?? NSApp.keyWindow ?? NSWindow() }
    }
}
