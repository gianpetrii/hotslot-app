import AppKit
import Combine
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var launchAtLogin = AppSettings.load().launchAtLogin
    @State private var playSound = AppSettings.load().playSoundOnPaste
    @State private var historyLimit = AppSettings.load().historyLimit
    @State private var debugClipboard = AppSettings.load().debugClipboard
    @State private var accessibilityTrusted = AccessibilityPermission.isTrusted

    var body: some View {
        TabView {
            HotkeysSettingsView()
                .tabItem { Label("Atajos", systemImage: "keyboard") }

            SlotsSettingsView(appState: appState)
                .tabItem { Label("Slots", systemImage: "square.grid.2x2") }

            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            permissionsTab
                .tabItem { Label("Permisos", systemImage: "lock.shield") }
        }
        .frame(width: 520, height: 420)
    }

    private var generalTab: some View {
        Form {
            Section("Inicio") {
                Toggle("Abrir al iniciar sesión", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(newValue)
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
        .padding()
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

                if accessibilityTrusted {
                    Button("Administrar en Ajustes del Sistema") {
                        AccessibilityPermission.openSettings()
                    }
                } else {
                    Button("Conceder acceso…") {
                        AccessibilityPermission.requestTrust(prompt: true)
                        accessibilityTrusted = AccessibilityPermission.isTrusted
                    }
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
