# Distribución directa (Developer ID)

HotSlot **v0.16+** se publica **fuera de la Mac App Store** para ofrecer pegado automático completo (Accesibilidad + atajos).

## Requisitos del desarrollador

- Cuenta [Apple Developer Program](https://developer.apple.com/programs/)
- Certificado **Developer ID Application**
- App-specific password para `notarytool` (Apple ID → contraseñas de app)

## Build local (Release)

```bash
brew install xcodegen
xcodegen generate
open HotSlot.xcodeproj
```

En Xcode: **Product → Archive** con esquema **HotSlot**, configuración **Release**.

## Script automatizado

```bash
./scripts/release-direct.sh
```

Variables opcionales:

| Variable | Descripción |
|----------|-------------|
| `DEVELOPER_ID` | Nombre del certificado (ej. `Developer ID Application: Tu Nombre (TEAMID)`) |
| `NOTARY_APPLE_ID` | Apple ID |
| `NOTARY_TEAM_ID` | Team ID |
| `NOTARY_PASSWORD` | App-specific password |

Salida en `build/release/`:

- `HotSlot.app`
- `HotSlot-<versión>.dmg` (si `create-dmg` está instalado: `brew install create-dmg`)

## Confianza del usuario

1. **Notarización** — obligatoria; sin stapler, Gatekeeper advierte.
2. **GitHub Release** — subí el `.dmg` + SHA-256 en las notas.
3. **Política de privacidad** — [privacy.html](privacy.html) (Accesibilidad explicada).
4. **Código** — repo público o fuentes accesibles.
5. **Soporte** — email en README / Issues de GitHub.

## Mac App Store

No se publica una build “lite” en la Store: confundiría a quien espera pegado automático universal.
