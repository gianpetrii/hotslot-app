# Slots — Monetización (acordado con producto)

## Modelo

| Fase | Duración | Qué incluye |
|------|----------|-------------|
| **Prueba** | **90 días** desde la **primera instalación / primer arranque** | App completa (5 slots, historial, atajos) |
| **Después** | — | **Solo slot 1** (pegar/guardar). Historial y slots 2–5 requieren licencia |
| **Compra** | Pago único **USD 10** | Desbloqueo permanente en ese Mac (clave local) |

## Canal de pago (v1)

- **Fuera de Mac App Store** (pegado con Accesibilidad).
- Checkout en web (**Lemon Squeezy**, Gumroad o página propia) → email con clave `SLOTS-XXXX-XXXX-XXXX`.
- Usuario pega la clave en **Ajustes → General → Licencia**.

## Implementación técnica

- `Entitlements.swift` — trial, gates, activación de clave (formato provisional).
- `docs/purchase.html` — copy pública y enlace de compra (placeholder hasta conectar pasarela).
- **Pendiente:** API de validación de claves (webhook de la pasarela + endpoint que firme claves reales).
- **Pendiente:** sustituir `LicenseKeyFormat` por HMAC o verificación server-side.

## Privacidad

- La clave se guarda en UserDefaults local (`AppSettings`).
- No hay cuenta obligatoria.
- Actualizar `privacy.html` cuando el checkout recopile email (pasarela).

## QA

- Probar trial: borrar `~/Library/Preferences/com.hotslot.app.plist` o contenedor de settings y reinstalar.
- Simular fin de trial: ajustar `firstInstallDate` en debug o esperar 90 días.
