import AppKit
import SwiftUI

/// Estado de las pantallas de inicio de sesión (opciones, email, restablecer, listo).
@MainActor @Observable
final class AccountFlowModel {
    enum Screen: Equatable {
        case options, email, reset, resetSent, done
    }

    enum EmailMode {
        case signIn, signUp
    }

    var screen: Screen = .options
    var mode: EmailMode = .signUp
    var email = ""
    var password = ""
    var errorMessage: String?
    var isBusy = false

    /// Primer arranque: muestra «Último paso · opcional».
    let isFirstRun: Bool
    let account: AccountService
    /// Ventana sobre la que se muestran los diálogos de Apple y Google.
    var presentingWindow: () -> NSWindow? = { NSApp.keyWindow }
    var onFinish: () -> Void = {}

    init(account: AccountService, isFirstRun: Bool) {
        self.account = account
        self.isFirstRun = isFirstRun
    }

    func go(_ next: Screen) {
        errorMessage = nil
        withAnimation(.easeOut(duration: 0.25)) { screen = next }
    }

    func back() {
        switch screen {
        case .options, .done: onFinish()
        case .email: go(.options)
        case .reset, .resetSent: go(.email)
        }
    }

    // MARK: Acciones

    func signInWithApple() {
        run { try await self.account.signInWithApple(presenting: self.presentingWindow()) }
    }

    func signInWithGoogle() {
        run { try await self.account.signInWithGoogle(presenting: self.presentingWindow()) }
    }

    func submitEmail() {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard address.contains("@"), address.contains(".") else {
            errorMessage = "Revisá el email."
            return
        }
        guard !password.isEmpty else {
            errorMessage = mode == .signUp ? "Elegí una contraseña." : "Escribí tu contraseña."
            return
        }
        run {
            if self.mode == .signUp {
                try await self.account.signUp(email: address, password: self.password)
            } else {
                try await self.account.signIn(email: address, password: self.password)
            }
        }
    }

    func sendReset() {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard address.contains("@"), address.contains(".") else {
            errorMessage = "Revisá el email."
            return
        }
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do {
                try await account.sendPasswordReset(email: address)
                go(.resetSent)
            } catch let failure as AccountService.Failure {
                errorMessage = failure.message.isEmpty ? nil : failure.message
            } catch {
                errorMessage = "No se pudo completar. Probá de nuevo."
            }
        }
    }

    /// Cancelar Apple o Google no muestra error: vuelve a las opciones como estaba.
    private func run(_ work: @escaping () async throws -> Void) {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do {
                try await work()
                password = ""
                go(.done)
            } catch let failure as AccountService.Failure {
                errorMessage = failure.message.isEmpty ? nil : failure.message
            } catch {
                errorMessage = "No se pudo completar. Probá de nuevo."
            }
        }
    }
}
