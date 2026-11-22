import AppKit
import SwiftUI

/// Confirmación con el estilo de la app (reemplaza los diálogos grises del sistema).
struct AppConfirmation {
    let title: String
    let message: String
    let confirmTitle: String
    /// Acciones que borran: el botón va como secundario en rojizo y «Cancelar» queda como principal.
    var destructive = false
    let action: () -> Void
}

/// Estado de las pantallas de inicio de sesión (opciones, email, restablecer, listo).
@MainActor @Observable
final class AccountFlowModel {
    enum Screen: Equatable {
        case options, email, reset, resetSent, done
        /// Pide la contraseña para eliminar la cuenta (cuentas con email).
        case confirmDelete
        /// Confirmación genérica (cerrar sesión, vaciar historial, restaurar atajos…).
        case confirm
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
    var showPassword = false
    var confirmation: AppConfirmation?
    /// Se ejecuta cuando la ventana ya se cerró (así la acción puede abrir otra sin chocar con esta).
    var afterClose: (() -> Void)?
    /// Respuesta de la confirmación para eliminar la cuenta: la contraseña, o nil si se cancela.
    var deleteCompletion: ((String?) -> Void)?
    /// Google abre el navegador: la ventana se retira mientras tanto para que no tape nada.
    var onBrowserFlow: (Bool) -> Void = { _ in }

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
        case .confirm:
            onFinish()
        case .confirmDelete:
            deleteCompletion?(nil)
            deleteCompletion = nil
            onFinish()
        case .email: go(.options)
        case .reset, .resetSent: go(.email)
        }
    }

    // MARK: Acciones

    func signInWithApple() {
        run { try await self.account.signInWithApple(presenting: self.presentingWindow()) }
    }

    func signInWithGoogle() {
        run(opensBrowser: true) { try await self.account.signInWithGoogle(presenting: self.presentingWindow()) }
    }

    func performConfirmation() {
        afterClose = confirmation?.action
        onFinish()
    }

    func confirmDelete() {
        guard !password.isEmpty else {
            errorMessage = "Escribí tu contraseña."
            return
        }
        deleteCompletion?(password)
        deleteCompletion = nil
        password = ""
        onFinish()
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
    private func run(opensBrowser: Bool = false, _ work: @escaping () async throws -> Void) {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        if opensBrowser { onBrowserFlow(true) }
        Task {
            defer {
                isBusy = false
                if opensBrowser { onBrowserFlow(false) }
            }
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
