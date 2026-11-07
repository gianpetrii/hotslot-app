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
    @State private var debugClipboard = AppSettings.load().debugClipboard
    @State private var confirmLibraryDelete = AppSettings.load().confirmLibraryDelete
    @State private var clickItemAction = AppSettings.load().clickItemAction
    @State private var accessibilityTrusted = AccessibilityPermission.isTrusted
    @State private var selectedTab: SettingsTab = .general
    @State private var licenseKeyInput = AppSettings.load().licenseKey ?? ""
    @State private var licensed = Entitlements.hasFullAccess

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label("General", systemImage: "gearshape")
                    .tag(SettingsTab.general)
                Label("Atajos", systemImage: "keyboard")
                    .tag(SettingsTab.hotkeys)
                Label("Permisos", systemImage: "lock.shield")
                    .tag(SettingsTab.permissions)
                Label("Slots", systemImage: "square.grid.2x2")
                    .tag(SettingsTab.slots)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 168, ideal: 188, max: 220)
        } detail: {
            Group {
                switch selectedTab {
                case .general:
                    generalTab
                case .hotkeys:
                    HotkeysSettingsView()
                        .padding()
                case .slots:
                    SlotsSettingsView(appState: appState)
                        .padding()
                case .permissions:
                    permissionsTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SlotsColor.papel.opacity(0.35))
        }
        .frame(width: 720, height: 540)
        .onAppear {
            confirmLibraryDelete = AppSettings.load().confirmLibraryDelete
            clickItemAction = AppSettings.load().clickItemAction
            if let pending = appState.pendingSettingsTab {
                selectedTab = pending
                appState.pendingSettingsTab = nil
            }
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
                        Text("Píldora negra ~1,5 s arriba al centro (bajo la cámara o la barra de menú). No es la Dynamic Island de iPhone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Probar aviso ahora") {
                            guard showNotchNotice else { return }
                            appState.presentNotch(.ready)
                        }
                        .disabled(!showNotchNotice)
                        Text("\(BrandDisplay.name) vive en la barra de menú (⌘ arriba a la derecha). Si no aparece, la barra está llena: mové ítems del sistema a Centro de control o reordená con ⌘+arrastrar. Atajo ⌘⇧V; también podés abrir desde Aplicaciones.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Licencia") {
                        licenseSectionBody
                    }
                    .id("settings-license")

                    Section("Barra de menú") {
                        Text("macOS no permite fijar el icono ⌘ por código. Arrastralo con ⌘ hacia la derecha (junto al reloj) para que no lo reemplacen otros iconos.")
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

                    Section("Depuración") {
                        Toggle("Modo depuración del portapapeles", isOn: $debugClipboard)
                            .onChange(of: debugClipboard) { _, newValue in
                                var settings = AppSettings.load()
                                settings.debugClipboard = newValue
                                settings.save()
                            }

                        if debugClipboard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(appState.clipboardService.debugStatus)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                Text("Ítems en historial: \(appState.historyStore.items.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Button("Forzar lectura ahora") {
                                    appState.clipboardService.pollNow()
                                }
                            }
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
            }
            .onAppear { scrollToLicenseIfNeeded(using: proxy) }
            .onChange(of: selectedTab) { _, tab in
                guard tab == .general else { return }
                scrollToLicenseIfNeeded(using: proxy)
            }
        }
        .padding()
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

                if !AccessibilityPermission.lastDiagnostic.isEmpty {
                    Text(AccessibilityPermission.lastDiagnostic)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { accessibilityTrusted = AccessibilityPermission.isTrusted }
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            accessibilityTrusted = AccessibilityPermission.isTrusted
        }
    }

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
