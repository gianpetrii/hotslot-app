import Foundation

/// Preferencias de la app persistidas en UserDefaults.
struct AppSettings: Codable, Equatable {
    var historyLimit: Int
    var launchAtLogin: Bool
    var playSoundOnPaste: Bool
    var debugClipboard: Bool

    static let `default` = AppSettings(
        historyLimit: 50,
        launchAtLogin: false,
        playSoundOnPaste: true,
        debugClipboard: false
    )

    private enum Keys {
        static let storage = "com.hotslot.appSettings"
    }

    private enum CodingKeys: String, CodingKey {
        case historyLimit, launchAtLogin, playSoundOnPaste, debugClipboard
    }

    init(historyLimit: Int, launchAtLogin: Bool, playSoundOnPaste: Bool, debugClipboard: Bool) {
        self.historyLimit = historyLimit
        self.launchAtLogin = launchAtLogin
        self.playSoundOnPaste = playSoundOnPaste
        self.debugClipboard = debugClipboard
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        historyLimit = try container.decodeIfPresent(Int.self, forKey: .historyLimit) ?? 50
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        playSoundOnPaste = try container.decodeIfPresent(Bool.self, forKey: .playSoundOnPaste) ?? true
        debugClipboard = try container.decodeIfPresent(Bool.self, forKey: .debugClipboard) ?? false
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
