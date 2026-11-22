import AppKit
import Combine
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var launchAtLogin = AppSettings.load().launchAtLogin
    @State private var playSound = AppSettings.load().playSoundOnPaste
    @State private var showNotchNotice = AppSettings.load().showNotchNotice
    @State private var historyLimit = AppSettings.load().historyLimit
    @State private var showNotchShelf = AppSettings.load().showNotchShelf
    @State private var notchHoverDelay = AppSettings.load().notchHoverDelay
    @State private var analyticsEnabled = AppSettings.load().analyticsEnabled
    @State private var confirmLibraryDelete = AppSettings.load().confirmLibraryDelete
    @State private var clickItemAction = AppSettings.load().clickItemAction
    @State private var accessibilityTrusted = AccessibilityPermission.isTrusted
    @State private var selectedTab: SettingsTab = .general
    @State private var licenseKeyInput = AppSettings.load().licenseKey ?? ""
    @State private var licensed = Entitlements.hasFullAccess

    @State private var showClearHistoryConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var accountBusy = false

    /// La pestaña Cuenta solo aparece si Firebase está configurado.
    private static var visibleTabs: [SettingsTab] { [.general, .hotkeys, .permissions, .account] }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            sidebar
                .frame(width: 180)

            VStack(alignment: .leading, spacing: 0) {
                SettingsTabTitle(text: selectedTab.title)
                    .id("title-\(selectedTab.rawValue)")
                    .transition(.opacity.combined(with: .offset(x: 16)))

                Group {
                    switch selectedTab {
                    case .general:
                        generalTab
                    case .hotkeys:
                        HotkeysSettingsView()
                    case .permissions:
                        permissionsTab
                    case .account:
                        accountTab
                    }
                }
                .id("tab-\(selectedTab.rawValue)")
                .transition(.opacity.combined(with: .offset(x: 16)))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.easeOut(duration: 0.22), value: selectedTab)
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 32)
        .padding(.top, 32)
        .padding(.bottom, 32)
        .frame(width: WindowPlacement.settingsWindowSize.width, height: WindowPlacement.settingsWindowSize.height)
        .background {
            // Vidrio con valores fijos (sin material que cambie con lo que hay detrás): ver handoff de Ajustes.
            ZStack {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow, cornerRadius: SlotsRadius.ventana)
                Color(slotsHex: 0xF6F1EB, opacity: 0.6)
            }
            .clipShape(RoundedRectangle(cornerRadius: SlotsRadius.ventana, style: .continuous))
        }
        .overlay {
            // Borde fino para que se note dónde termina la ventana.
            RoundedRectangle(cornerRadius: SlotsRadius.ventana, style: .continuous)
                .strokeBorder(Color.white.opacity(0.75), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .environment(\.colorScheme, .light)
        .onAppear {
            confirmLibraryDelete = AppSettings.load().confirmLibraryDelete
            clickItemAction = AppSettings.load().clickItemAction
            if let pending = appState.pendingSettingsTab {
                selectedTab = pending
                appState.pendingSettingsTab = nil
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer().frame(height: 6)
            ForEach(Self.visibleTabs, id: \.self) { tab in
                SettingsSidebarItem(
                    title: tab.title,
                    isSelected: selectedTab == tab,
                    badge: tab == .permissions ? (accessibilityTrusted ? .ok : .missing) : .none
                ) {
                    withAnimation(.easeOut(duration: 0.22)) { selectedTab = tab }
                }
            }

            Spacer(minLength: 0)

            Text("\(BrandDisplay.name) \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(SettingsStyle.regular(12))
                .foregroundStyle(SlotsColor.textoSecundario)
                .padding(.leading, SlotsSpace.xs)
        }
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            accessibilityTrusted = AccessibilityPermission.isTrusted
        }
    }

    private func saveSetting(_ change: (inout AppSettings) -> Void) {
        var settings = AppSettings.load()
        change(&settings)
        settings.save()
    }

    private func linkRow(_ title: String, detail: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SettingsRow(title: title, detail: detail) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SettingsStyle.chevron)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var generalTab: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 27) {
                    SettingsSection("Inicio") {
                        SettingsCard {
                            SettingsRow(title: "Abrir al iniciar sesión") {
                                SettingsSwitch(isOn: $launchAtLogin)
                            }
                            SettingsRow(
                                title: "Mostrar aviso en el notch",
                                detail: "Aviso breve arriba al centro, bajo el notch o la barra de menú. Negro al confirmar, naranja si pide una acción."
                            ) {
                                SettingsSwitch(isOn: $showNotchNotice)
                            }
                        }
                    }
                    .onChange(of: launchAtLogin) { _, newValue in updateLaunchAtLogin(newValue) }
                    .onChange(of: showNotchNotice) { _, newValue in
                        saveSetting { $0.showNotchNotice = newValue }
                    }

                    SettingsSection("Barra del notch") {
                        SettingsCard {
                            SettingsRow(
                                title: "Mostrar la barra al pasar el mouse por el notch",
                                detail: "Muestra tus slots y bibliotecas al pasar por el notch (o el centro de la barra de menú). También se abre al arrastrar un archivo hacia ahí."
                            ) {
                                SettingsSwitch(isOn: $showNotchShelf)
                            }
                            SettingsRow(
                                title: "Tiempo para abrir",
                                detail: "Cuánto hay que dejar el mouse sobre el notch para que se abra la barra. Evita aperturas sin querer.",
                                disabled: !showNotchShelf
                            ) {
                                SettingsOptions(
                                    options: [(0.15, "Rápido"), (0.3, "Normal"), (0.6, "Lento")],
                                    selection: $notchHoverDelay
                                )
                            }
                        }
                    }
                    .onChange(of: notchHoverDelay) { _, newValue in
                        saveSetting { $0.notchHoverDelay = newValue }
                        NotificationCenter.default.post(name: .notchShelfSettingChanged, object: nil)
                    }
                    .onChange(of: showNotchShelf) { _, newValue in
                        saveSetting { $0.showNotchShelf = newValue }
                        NotificationCenter.default.post(name: .notchShelfSettingChanged, object: nil)
                    }

                    SettingsSection("Licencia") {
                        SettingsCard {
                            licenseSectionBody
                        }
                    }
                    .id("settings-license")

                    SettingsSection("Barra de menú") {
                        SettingsCard {
                            linkRow(
                                "Cómo mantener \(BrandDisplay.name) visible…",
                                detail: "macOS no permite fijar el ícono de \(BrandDisplay.name) por código. Arrastralo con ⌘ hacia la derecha (junto al reloj) para que no lo reemplacen otros íconos."
                            ) {
                                appState.suppressSettingsAutoClose()
                                MenuBarGuide.present()
                            }
                        }
                    }

                    SettingsSection("Al hacer clic en un slot o el historial") {
                        SettingsCard {
                            SettingsRow(title: "Acción", detail: clickItemAction.caption) {
                                SettingsPicker(
                                    options: ClickItemAction.allCases.map { ($0, $0.title) },
                                    selection: $clickItemAction
                                )
                            }
                        }
                    }
                    .onChange(of: clickItemAction) { _, newValue in
                        saveSetting { $0.clickItemAction = newValue }
                    }

                    SettingsSection("Bibliotecas") {
                        SettingsCard {
                            SettingsRow(title: "Confirmar antes de eliminar una biblioteca") {
                                SettingsSwitch(isOn: $confirmLibraryDelete)
                            }
                        }
                    }
                    .onChange(of: confirmLibraryDelete) { _, newValue in
                        appState.setConfirmLibraryDelete(newValue)
                    }

                    SettingsSection("Historial") {
                        SettingsCard {
                            SettingsRow(title: "Límite: \(historyLimit) ítems") {
                                SettingsStepper(value: $historyLimit, range: 10...500, step: 10)
                            }
                            SettingsRow(title: "Vaciar historial", destructive: true) {
                                SettingsPillButton(title: "Vaciar") {
                                    showClearHistoryConfirmation = true
                                }
                            }
                        }
                    }
                    .onChange(of: historyLimit) { _, newValue in
                        saveSetting { $0.historyLimit = newValue }
                        appState.historyStore.historyLimit = newValue
                    }

                    SettingsSection("Sonido") {
                        SettingsCard {
                            SettingsRow(
                                title: "Sonidos de acciones",
                                detail: "Pegar, guardar en un slot o cuando no se puede completar la acción."
                            ) {
                                SettingsSwitch(isOn: $playSound)
                            }
                        }
                    }
                    .onChange(of: playSound) { _, newValue in
                        saveSetting { $0.playSoundOnPaste = newValue }
                    }

                    if Telemetry.isConfigured {
                        SettingsSection("Privacidad") {
                            SettingsCard {
                                SettingsRow(
                                    title: "Compartir uso anónimo",
                                    detail: "Cuenta qué funciones se usan, sin enviar lo que copiás, nombres de archivos, bibliotecas o slots, ni quién sos. Apagado por defecto."
                                ) {
                                    SettingsSwitch(isOn: $analyticsEnabled)
                                }
                                linkRow("Política de privacidad") {
                                    appState.suppressSettingsAutoClose(for: 30)
                                    NSWorkspace.shared.open(Self.privacyURL)
                                }
                            }
                        }
                        .onChange(of: analyticsEnabled) { _, newValue in
                            saveSetting {
                                $0.analyticsEnabled = newValue
                                $0.hasAnsweredAnalyticsPrompt = true
                            }
                            Telemetry.consentChanged()
                        }
                    }

                    SettingsSection("Ayuda") {
                        SettingsCard {
                            linkRow("Cómo usar \(BrandDisplay.name)") {
                                appState.openTutorial?()
                            }
                        }
                    }

                    SettingsSection("Acerca de") {
                        SettingsCard {
                            SettingsRow(title: "Versión") {
                                SettingsValue(text: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            }
                        }
                        Button {
                            appState.suppressSettingsAutoClose(for: 30)
                            NSWorkspace.shared.open(Self.iconAttributionURL)
                        } label: {
                            Text("Reporte iconos creados por Magnific - Flaticon")
                                .font(SettingsStyle.regular(13))
                                .foregroundStyle(SlotsColor.textoSecundario)
                                .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .confirmationDialog(
                "¿Vaciar el historial?",
                isPresented: $showClearHistoryConfirmation,
                titleVisibility: .visible
            ) {
                Button("Vaciar historial", role: .destructive) {
                    appState.historyStore.clear()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se borran los ítems del historial. Los slots no se tocan.")
            }
            .onAppear { scrollToLicenseIfNeeded(using: proxy) }
            .onChange(of: selectedTab) { _, tab in
                guard tab == .general else { return }
                scrollToLicenseIfNeeded(using: proxy)
            }
        }
    }

    @ViewBuilder
    private var licenseSectionBody: some View {
        if Entitlements.hasFullAccess {
            if AppSettings.load().isLicensed {
                SettingsTextRow(text: "Compra activa")
            } else if let end = Entitlements.trialEndsAt {
                SettingsTextRow(text: "Prueba gratuita hasta \(end.formatted(date: .abbreviated, time: .omitted))")
            }
        } else {
            SettingsTextRow(text: "La prueba terminó. Comprá una licencia (USD 10, pago único) o seguí usando solo el slot 1.")
        }

        SettingsRow(title: "Clave del email de compra (UUID)") {
            SettingsTextField(placeholder: "", text: $licenseKeyInput, width: 232)
        }

        HStack(spacing: 8) {
            Spacer()
            SettingsPillButton(title: "Comprar…") {
                appState.openPurchasePage()
            }
            SettingsPillButton(title: "Activar licencia", kind: .primary) {
                Task {
                    if let error = await Entitlements.activateLicenseKeyOnline(licenseKeyInput) {
                        appState.showToast(error)
                    } else {
                        licensed = true
                        appState.showToast("Licencia activada — gracias")
                    }
                }
            }
        }
        .padding(.vertical, 14)
    }

    private func scrollToLicenseIfNeeded(using proxy: ScrollViewProxy) {
        guard appState.pendingScrollToLicense else { return }
        appState.pendingScrollToLicense = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo("settings-license", anchor: .top)
            }
        }
    }

    // MARK: Cuenta

    private var accountTab: some View {
        let account = appState.account
        return ScrollView {
            VStack(alignment: .leading, spacing: 27) {
                SettingsSection {
                    SettingsCard {
                        if let profile = account.profile {
                            SettingsRow(title: profile.email ?? "Cuenta de Slots", detail: "Conectada con \(profile.provider.title)") {
                                SettingsPillButton(title: "Cerrar sesión") { showSignOutConfirmation = true }
                            }
                        } else {
                            SettingsRow(
                                title: "Sin sesión iniciada",
                                detail: "Iniciá sesión para tener tu cuenta de Slots. Más adelante vas a poder guardar tu licencia ahí y sincronizar con el iPhone."
                            ) {
                                SettingsPillButton(title: "Iniciar sesión", kind: .primary) {
                                    appState.openAccount?()
                                }
                                .disabled(!account.isConfigured)
                            }
                        }
                        SettingsRow(
                            title: "Sincronización",
                            detail: "Próximamente. Vas a necesitar una cuenta.",
                            disabled: true
                        ) {
                            SettingsSwitch(isOn: .constant(false))
                        }
                    }
                }

                if account.profile != nil {
                    SettingsSection("Zona de cuidado") {
                        SettingsCard {
                            SettingsRow(
                                title: "Eliminar cuenta",
                                detail: "Borra tu cuenta y sus datos en la nube. No borra los slots de esta Mac.",
                                destructive: true
                            ) {
                                SettingsPillButton(title: accountBusy ? "Eliminando…" : "Eliminar") {
                                    showDeleteAccountConfirmation = true
                                }
                                .disabled(accountBusy)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog("¿Cerrar sesión?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Cerrar sesión") { appState.account.signOut() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Tus slots siguen en esta Mac.")
        }
        .confirmationDialog("¿Eliminar tu cuenta?", isPresented: $showDeleteAccountConfirmation, titleVisibility: .visible) {
            Button("Eliminar cuenta", role: .destructive) { deleteAccount() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borra tu cuenta y sus datos en la nube. No se puede deshacer. Tus slots en esta Mac no se tocan.")
        }
    }

    private func deleteAccount() {
        guard let profile = appState.account.profile else { return }
        accountBusy = true
        appState.suppressSettingsAutoClose(for: 600)
        Task {
            defer {
                accountBusy = false
                appState.setSettingsFloating?(true)
                appState.releaseSettingsAutoClose()
            }
            do {
                var password: String?
                if profile.provider == .email {
                    // Firebase pide la contraseña para confirmar: se pide con la tarjeta de la app.
                    password = await withCheckedContinuation { continuation in
                        guard let ask = appState.askDeletePassword else { continuation.resume(returning: nil); return }
                        ask { continuation.resume(returning: $0) }
                    }
                    guard password != nil else { return }
                }
                // Google abre el navegador: Ajustes se baja para que el navegador quede primero.
                if profile.provider == .google { appState.setSettingsFloating?(false) }
                try await appState.account.deleteAccount(password: password, presenting: NSApp.keyWindow)
                appState.showToast("Cuenta eliminada")
            } catch let failure as AccountService.Failure {
                if !failure.message.isEmpty { appState.showToast(failure.message) }
            } catch {
                appState.showToast("No se pudo eliminar la cuenta. Probá de nuevo.")
            }
        }
    }

    private var permissionsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsSection("Accesibilidad") {
                    SettingsCard {
                        SettingsRow(
                            title: "Estado",
                            detail: "Hace falta para pegar automáticamente el ítem elegido en la app donde estabas."
                        ) {
                            SettingsPermissionChip(granted: accessibilityTrusted) {
                                appState.suppressSettingsAutoClose()
                                AccessibilityPermission.requestAccessForPaste(focusWindow: appState.accessibilityPresentingWindow)
                            }
                        }
                        SettingsRow(title: accessibilityTrusted ? "Permiso concedido" : "Cómo darlo") {
                            VStack(alignment: .trailing, spacing: 8) {
                                AccessibilityGrantSection(isTrusted: $accessibilityTrusted)
                            }
                        }
                    }
                }

                if !accessibilityTrusted {
                    SettingsNote(text: AccessibilityPermissionCopy.promptFirst)
                    if DevelopmentAppInstall.runsFromDerivedData {
                        SettingsNote(text: "Desde Xcode, macOS casi nunca muestra el aviso TCC: el botón principal copia a /Applications/Slots.app y relanza la app desde ahí.")
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .onAppear { accessibilityTrusted = AccessibilityPermission.isTrusted }
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            accessibilityTrusted = AccessibilityPermission.isTrusted
        }
    }

    private static let privacyURL = URL(string: "https://hotslot-app-docs.vercel.app/privacy.html")!
    private static let iconAttributionURL = URL(string: "https://www.flaticon.es/iconos-gratis/reporte")!

    private func updateLaunchAtLogin(_ enabled: Bool) {
        var settings = AppSettings.load()
        settings.launchAtLogin = enabled
        settings.save()
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            appState.showToast("No se pudo configurar inicio automático")
        }
    }
}

/// Pill del menú lateral: 48 de alto, activa en negro.
struct SettingsSidebarItem: View {
    enum Badge { case none, ok, missing }

    let title: String
    let isSelected: Bool
    var badge: Badge = .none
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(SettingsStyle.medium(14))
                Spacer(minLength: 4)
                switch badge {
                case .none:
                    EmptyView()
                case .ok:
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(SlotsColor.naranja))
                case .missing:
                    Text("!")
                        .font(SettingsStyle.semibold(12))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(SlotsColor.tinta))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .foregroundStyle(isSelected ? Color.white : SlotsColor.tinta)
            .background {
                Capsule(style: .continuous)
                    .fill(isSelected ? SlotsColor.tinta : Color.white.opacity(isHovering ? 0.8 : 0.5))
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
