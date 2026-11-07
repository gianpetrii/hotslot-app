import Foundation

/// Qué hace un clic en un slot o en un ítem del historial.
enum ClickItemAction: String, Codable, CaseIterable, Identifiable {
    case copyToClipboard
    case pasteAtFocus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .copyToClipboard: return "Copiar al portapapeles"
        case .pasteAtFocus: return "Pegar donde estaba el cursor"
        }
    }

    var caption: String {
        switch self {
        case .copyToClipboard:
            return "El clic deja el contenido copiado; lo pegás vos con ⌘V donde quieras. Los atajos de teclado siguen pegando solos."
        case .pasteAtFocus:
            return "El clic pega en la app que tenías delante, igual que los atajos. Hace falta permiso de Accesibilidad."
        }
    }
}

/// Preferencias de la app persistidas en UserDefaults.
struct AppSettings: Codable, Equatable {
    var historyLimit: Int
    var launchAtLogin: Bool
    var playSoundOnPaste: Bool
    var showNotchNotice: Bool
    var clickItemAction: ClickItemAction
    var debugClipboard: Bool
    var hasCompletedOnboarding: Bool
    var hasSeenMenuBarHint: Bool
    var firstInstallDate: Date?
    var licenseKey: String?
    var isLicensed: Bool
    var confirmLibraryDelete: Bool

    static let `default` = AppSettings(
        historyLimit: 50,
        launchAtLogin: false,
        playSoundOnPaste: true,
        showNotchNotice: true,
        clickItemAction: .copyToClipboard,
        debugClipboard: false,
        hasCompletedOnboarding: false,
        hasSeenMenuBarHint: false,
        firstInstallDate: nil,
        licenseKey: nil,
        isLicensed: false
    )

    private enum Keys {
        static let storage = "com.hotslot.appSettings"
    }

    private enum CodingKeys: String, CodingKey {
        case historyLimit, launchAtLogin, playSoundOnPaste, showNotchNotice, clickItemAction, debugClipboard, hasCompletedOnboarding, hasSeenMenuBarHint
        case firstInstallDate, licenseKey, isLicensed, confirmLibraryDelete
    }

    init(
        historyLimit: Int,
        launchAtLogin: Bool,
        playSoundOnPaste: Bool,
        showNotchNotice: Bool = true,
        clickItemAction: ClickItemAction = .copyToClipboard,
        debugClipboard: Bool,
        hasCompletedOnboarding: Bool,
        hasSeenMenuBarHint: Bool = false,
        firstInstallDate: Date? = nil,
        licenseKey: String? = nil,
        isLicensed: Bool = false,
        confirmLibraryDelete: Bool = true
    ) {
        self.historyLimit = historyLimit
        self.launchAtLogin = launchAtLogin
        self.playSoundOnPaste = playSoundOnPaste
        self.showNotchNotice = showNotchNotice
        self.clickItemAction = clickItemAction
        self.debugClipboard = debugClipboard
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.hasSeenMenuBarHint = hasSeenMenuBarHint
        self.firstInstallDate = firstInstallDate
        self.licenseKey = licenseKey
        self.isLicensed = isLicensed
        self.confirmLibraryDelete = confirmLibraryDelete
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        historyLimit = try container.decodeIfPresent(Int.self, forKey: .historyLimit) ?? 50
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        playSoundOnPaste = try container.decodeIfPresent(Bool.self, forKey: .playSoundOnPaste) ?? true
        showNotchNotice = try container.decodeIfPresent(Bool.self, forKey: .showNotchNotice) ?? true
        clickItemAction = try container.decodeIfPresent(ClickItemAction.self, forKey: .clickItemAction) ?? .copyToClipboard
        debugClipboard = try container.decodeIfPresent(Bool.self, forKey: .debugClipboard) ?? false
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        hasSeenMenuBarHint = try container.decodeIfPresent(Bool.self, forKey: .hasSeenMenuBarHint) ?? false
        firstInstallDate = try container.decodeIfPresent(Date.self, forKey: .firstInstallDate)
        licenseKey = try container.decodeIfPresent(String.self, forKey: .licenseKey)
        isLicensed = try container.decodeIfPresent(Bool.self, forKey: .isLicensed) ?? false
        confirmLibraryDelete = try container.decodeIfPresent(Bool.self, forKey: .confirmLibraryDelete) ?? true
    }

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: Keys.storage),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Keys.storage)
    }
}
