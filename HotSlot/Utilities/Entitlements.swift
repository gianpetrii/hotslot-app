import Foundation

/// Trial 90 días desde la primera instalación; después solo slot 1 sin licencia.
/// Pago único USD 10 vía web + clave (ver `docs/MONETIZATION.md`).
enum Entitlements {
    static let trialDurationDays = 90
    static let freeSlotIndexAfterTrial = 1

    /// URL de compra (Lemon Squeezy / Gumroad / página propia). Actualizar al activar cobros.
    static let purchaseURL = URL(string: "https://hotslot-app-docs.vercel.app/purchase.html")!

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

    @discardableResult
    static func activateLicenseKey(_ raw: String) -> Bool {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard LicenseKeyFormat.isValid(key) else { return false }
        var settings = AppSettings.load()
        settings.licenseKey = key
        settings.isLicensed = true
        settings.save()
        return true
    }
}

/// Formato provisional `SLOTS-XXXX-XXXX-XXXX` (checksum simple; reemplazar por validación server-side).
enum LicenseKeyFormat {
    static func isValid(_ key: String) -> Bool {
        let parts = key.split(separator: "-")
        guard parts.count == 4, parts[0] == "SLOTS" else { return false }
        return parts.dropFirst().allSatisfy { part in
            part.count == 4 && part.allSatisfy { ch in
                ch.isASCII && (ch.isNumber || ("A" ... "Z").contains(ch))
            }
        }
    }
}
