import Foundation

/// Preferencias de la app persistidas en UserDefaults.
struct AppSettings: Codable, Equatable {
    var historyLimit: Int
    var launchAtLogin: Bool
    var playSoundOnPaste: Bool
    var debugClipboard: Bool
    var hasCompletedOnboarding: Bool
    var hasSeenMenuBarHint: Bool
    var firstInstallDate: Date?
    var licenseKey: String?
    var isLicensed: Bool

    static let `default` = AppSettings(
        historyLimit: 50,
        launchAtLogin: false,
        playSoundOnPaste: true,
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
        case historyLimit, launchAtLogin, playSoundOnPaste, debugClipboard, hasCompletedOnboarding, hasSeenMenuBarHint
        case firstInstallDate, licenseKey, isLicensed
    }

    init(
        historyLimit: Int,
        launchAtLogin: Bool,
        playSoundOnPaste: Bool,
        debugClipboard: Bool,
        hasCompletedOnboarding: Bool,
        hasSeenMenuBarHint: Bool = false,
        firstInstallDate: Date? = nil,
        licenseKey: String? = nil,
        isLicensed: Bool = false
    ) {
        self.historyLimit = historyLimit
        self.launchAtLogin = launchAtLogin
        self.playSoundOnPaste = playSoundOnPaste
        self.debugClipboard = debugClipboard
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.hasSeenMenuBarHint = hasSeenMenuBarHint
        self.firstInstallDate = firstInstallDate
        self.licenseKey = licenseKey
        self.isLicensed = isLicensed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        historyLimit = try container.decodeIfPresent(Int.self, forKey: .historyLimit) ?? 50
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        playSoundOnPaste = try container.decodeIfPresent(Bool.self, forKey: .playSoundOnPaste) ?? true
        debugClipboard = try container.decodeIfPresent(Bool.self, forKey: .debugClipboard) ?? false
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        hasSeenMenuBarHint = try container.decodeIfPresent(Bool.self, forKey: .hasSeenMenuBarHint) ?? false
        firstInstallDate = try container.decodeIfPresent(Date.self, forKey: .firstInstallDate)
        licenseKey = try container.decodeIfPresent(String.self, forKey: .licenseKey)
        isLicensed = try container.decodeIfPresent(Bool.self, forKey: .isLicensed) ?? false
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
