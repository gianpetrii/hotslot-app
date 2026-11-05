import Foundation

/// Trial 90 días desde la primera instalación; después solo slot 1 sin licencia.
/// Pago único USD 10 vía Lemon Squeezy (modelo en `docs/DECISIONES-REDISENO.md`).
enum Entitlements {
    static let trialDurationDays = 90
    static let freeSlotIndexAfterTrial = 1

    /// Checkout publicado en Lemon Squeezy.
    static let purchaseURL = URL(string: "https://slots.lemonsqueezy.com/checkout/buy/a2e83610-199d-4d93-91f4-32d63f57d05d")!

    static func recordFirstLaunchIfNeeded() {
        var settings = AppSettings.load()
        guard settings.firstInstallDate == nil else { return }
        settings.firstInstallDate = Date()
        settings.save()
    }

    static var hasFullAccess: Bool {
        let settings = AppSettings.load()
        if settings.isLicensed { return true }
        guard let start = settings.firstInstallDate else { return true }
        let end = Calendar.current.date(byAdding: .day, value: trialDurationDays, to: start) ?? start
        return Date() < end
    }

    static var trialEndsAt: Date? {
        guard let start = AppSettings.load().firstInstallDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: trialDurationDays, to: start)
    }

    static func canUseSlot(index: Int) -> Bool {
        hasFullAccess || index == freeSlotIndexAfterTrial
    }

    static var canUseHistoryAndExtraSlots: Bool {
        hasFullAccess
    }

    /// Clave local de desarrollo (sin Lemon).
    @discardableResult
    static func activateLicenseKey(_ raw: String) -> Bool {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard LicenseKeyFormat.isLegacySlotsKey(key) else { return false }
        var settings = AppSettings.load()
        settings.licenseKey = key
        settings.isLicensed = true
        settings.save()
        return true
    }

    @MainActor
    static func activateLicenseKeyOnline(_ raw: String) async -> String? {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if LicenseKeyFormat.isLegacySlotsKey(key.uppercased()) {
            activateLicenseKey(key)
            return nil
        }

        let result = await LemonLicenseService.activate(licenseKey: key)
        if result.success {
            var settings = AppSettings.load()
            settings.licenseKey = key
            settings.isLicensed = true
            settings.save()
            return nil
        }
        return result.message
    }
}

enum LicenseKeyFormat {
    /// Formato Lemon Squeezy (UUID).
    static func isLemonKey(_ key: String) -> Bool {
        let pattern = #"^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"#
        return key.range(of: pattern, options: .regularExpression) != nil
    }

    /// Solo para pruebas locales / QA.
    static func isLegacySlotsKey(_ key: String) -> Bool {
        let parts = key.split(separator: "-")
        guard parts.count == 4, parts[0] == "SLOTS" else { return false }
        return parts.dropFirst().allSatisfy { part in
            part.count == 4 && part.allSatisfy { ch in
                ch.isASCII && (ch.isNumber || ("A" ... "Z").contains(ch))
            }
        }
    }
}
