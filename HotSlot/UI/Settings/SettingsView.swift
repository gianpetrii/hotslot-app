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
    @State private var analyticsEnabled = AppSettings.load().analyticsEnabled
    @State private var confirmLibraryDelete = AppSettings.load().confirmLibraryDelete
    @State private var clickItemAction = AppSettings.load().clickItemAction
    @State private var accessibilityTrusted = AccessibilityPermission.isTrusted
    @State private var selectedTab: SettingsTab = .general
    @State private var licenseKeyInput = AppSettings.load().licenseKey ?? ""
    @State private var licensed = Entitlements.hasFullAccess

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sidebar
                .frame(width: 188)

            VStack(alignment: .leading, spacing: SlotsSpace.s) {
                Text(selectedTab.title)
                    .font(SlotsFont.tituloPantalla(true))
                    .foregroundStyle(SlotsColor.tinta)
                    .padding(.horizontal, SlotsSpace.l)
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
                    }
                }
                .id("tab-\(selectedTab.rawValue)")
                .transition(.opacity.combined(with: .offset(x: 16)))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.easeOut(duration: 0.22), value: selectedTab)
            .clipped()
            .padding(.top, SlotsSpace.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 720, height: 540)
        .background {
            LinearGradient(
                colors: [Color(slotsHex: 0xEFE7DC), Color(slotsHex: 0xE7DED2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
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
        VStack(alignment: .leading, spacing: SlotsSpace.s) {
            ForEach([SettingsTab.general, .hotkeys, .permissions], id: \.self) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.22)) { selectedTab = tab }
                } label: {
                    HStack {
                        Text(tab.title)
                            .font(SlotsFont.textoUI)
                        Spacer(minLength: 4)
                        if tab == .permissions, accessibilityTrusted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(SlotsColor.naranja))
                        }
                    }
                    .padding(.horizontal, SlotsSpace.m)
                    .frame(height: 44)
                    .foregroundStyle(selectedTab == tab ? Color.white : SlotsColor.tinta)
                    .background {
                        Capsule(style: .continuous)
                            .fill(selectedTab == tab ? SlotsColor.tinta : Color.white.opacity(0.7))
                    }
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            Text("\(BrandDisplay.name) \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(SlotsFont.etiqueta)
                .foregroundStyle(SlotsColor.textoSecundario)
                .padding(.leading, SlotsSpace.xs)
        }
        .padding(.horizontal, SlotsSpace.m)
        .padding(.top, SlotsSpace.xl)
        .padding(.bottom, SlotsSpace.m)
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            accessibilityTrusted = AccessibilityPermission.isTrusted
        }
    }

    private var generalTab: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Form {
                    Section("Inicio") {
                        Toggle("Abrir al iniciar sesión", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { _, newValue in
                                updateLaunchAtLogin(newValue)
                            }
                        Toggle("Mostrar aviso en el notch", isOn: $showNotchNotice)
                            .onChange(of: showNotchNotice) { _, newValue in
                                var settings = AppSettings.load()
                                settings.showNotchNotice = newValue
                                settings.save()
                            }
                        Text("Aviso breve arriba al centro, bajo el notch o la barra de menú. Negro al confirmar, naranja si pide una acción.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Barra del notch") {
                        Toggle("Mostrar la barra al pasar el mouse por el notch", isOn: $showNotchShelf)
                            .onChange(of: showNotchShelf) { _, newValue in
                                var settings = AppSettings.load()
                                settings.showNotchShelf = newValue
                                settings.save()
                                NotificationCenter.default.post(name: .notchShelfSettingChanged, object: nil)
                            }
                        Text("Muestra tus slots y bibliotecas al pasar por el notch (o el centro de la barra de menú). También se abre al arrastrar un archivo hacia ahí.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Licencia") {
                        licenseSectionBody
                    }
                    .id("settings-license")

                    Section("Barra de menú") {
                        Text("macOS no permite fijar el ícono de \(BrandDisplay.name) por código. Arrastralo con ⌘ hacia la derecha (junto al reloj) para que no lo reemplacen otros íconos.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button("Cómo mantener \(BrandDisplay.name) visible…") {
                            MenuBarGuide.present()
                        }
                    }

                    Section("Al hacer clic en un slot o el historial") {
                        Picker("Acción", selection: $clickItemAction) {
                            ForEach(ClickItemAction.allCases) { action in
                                Text(action.title).tag(action)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .onChange(of: clickItemAction) { _, newValue in
                            var current = AppSettings.load()
                            current.clickItemAction = newValue
                            current.save()
                        }
                        Text(clickItemAction.caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Bibliotecas") {
                        Toggle("Confirmar antes de eliminar una biblioteca", isOn: $confirmLibraryDelete)
                            .onChange(of: confirmLibraryDelete) { _, newValue in
                                appState.setConfirmLibraryDelete(newValue)
                            }
                    }

                    Section("Historial") {
                        Stepper("Límite: \(historyLimit) ítems", value: $historyLimit, in: 10...500, step: 10)
                            .onChange(of: historyLimit) { _, newValue in
                                var settings = AppSettings.load()
                                settings.historyLimit = newValue
                                settings.save()
                                appState.historyStore.historyLimit = newValue
                            }

                        Button("Vaciar historial", role: .destructive) {
                            appState.historyStore.clear()
                        }
                    }

                    Section("Sonido") {
                        Toggle("Sonidos de acciones", isOn: $playSound)
                            .onChange(of: playSound) { _, newValue in
                                var settings = AppSettings.load()
                                settings.playSoundOnPaste = newValue
                                settings.save()
                            }
                        Text("Pegar, guardar en un slot o cuando no se puede completar la acción.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if Telemetry.isConfigured {
                        Section("Privacidad") {
                            Toggle("Compartir uso anónimo", isOn: $analyticsEnabled)
                                .onChange(of: analyticsEnabled) { _, newValue in
                                    var settings = AppSettings.load()
                                    settings.analyticsEnabled = newValue
                                    settings.hasAnsweredAnalyticsPrompt = true
                                    settings.save()
                                    Telemetry.consentChanged()
                                }
                            Text("Cuenta qué funciones se usan, sin enviar lo que copiás, nombres de archivos, bibliotecas o slots, ni quién sos. Apagado por defecto.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Link("Política de privacidad", destination: Self.privacyURL)
                        }
                    }

                    Section("Ayuda") {
                        Button("Cómo usar \(BrandDisplay.name)") {
                            appState.openOnboarding?()
                        }
                    }

                    Section {
                        LabeledContent("Versión", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    } header: {
                        Text("Acerca de")
                    } footer: {
                        Link(destination: Self.iconAttributionURL) {
                            Text("Reporte iconos creados por Magnific - Flaticon")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
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
                Label("Compra activa", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else if let end = Entitlements.trialEndsAt {
                Text("Prueba gratuita hasta \(end.formatted(date: .abbreviated, time: .omitted))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("La prueba terminó. Comprá una licencia (USD 10, pago único) o seguí usando solo el slot 1.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }

        TextField("Clave del email de compra (UUID)", text: $licenseKeyInput)
            .textFieldStyle(.roundedBorder)

        HStack {
            Button("Activar licencia") {
                Task {
                    if let error = await Entitlements.activateLicenseKeyOnline(licenseKeyInput) {
                        appState.showToast(error)
                    } else {
                        licensed = true
                        appState.showToast("Licencia activada — gracias")
                    }
                }
            }
            Button("Comprar…") {
                appState.openPurchasePage()
            }
        }
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

    private var permissionsTab: some View {
        Form {
            Section("Accesibilidad") {
                LabeledContent("Estado") {
                    Text(accessibilityTrusted ? "Concedido" : "No concedido")
                        .foregroundStyle(accessibilityTrusted ? Color.green : Color.orange)
                }

                Text("Hace falta para pegar automáticamente el ítem elegido en la app donde estabas.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                AccessibilityGrantSection(isTrusted: $accessibilityTrusted, style: .settingsForm)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
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
