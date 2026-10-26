# HotSlot

Clipboard manager nativo para macOS con historial, slots fijos y atajos globales.

## Requisitos

- macOS 14.0+
- Xcode 15+

## Versiones

| Tag | Descripción |
|-----|-------------|
| `v0.1.0` | MVP funcional: clipboard, slots, hotkeys |
| `v0.2.0` | UI estilo Control Center (vibrancy + glass) |
| `v0.3.0` | Animaciones Spotlight, backdrop blur, tipografía nativa |
| `v0.4.0` | Pegado automático fiable, historial nativo (pin, busca, thumbs) y permisos claros |
| `v0.5.0` | Unfold de apertura, filas más densas y grabador de atajos en app de menú |
| `v0.6.0` | Layout dos columnas, hover con dwell, intercambio de slots y vaciar con ✕ |
| `v0.7.0` | Drag de slots intercambia contenido; el panel se mueve desde el buscador |
| `v0.8.0` | Overlay de slots, atajos en caliente y arrastrar historial a un slot |
| `v0.9.0` | Peek de slots al hover; texto del peek se ajusta al contenido |
| `v0.10.0` | Sonidos por acción; guardar la selección en el slot; error si no hay destino |
| `v0.11.0` | Atajos A/S/D/Q/W; Ajustes animados; pegado otra vez en Chrome y Cursor |
| `v0.12.0` | Ícono de app; orden persistente de pines en el historial |
| `v0.13.0` | Hover de filas; paste espera el foco; metadata en español; aviso de atajos |
| `v0.15.0` | Onboarding interactivo; App Sandbox (intento Mac App Store) |
| `v0.16.0` | **Release pública directa** — pegado completo (Accesibilidad + CGEvent) |

## Nota sobre logs en Xcode

Los mensajes `com.apple.linkd.autoShortcut` son **ruido del sistema** (Intents/Shortcuts al registrar hotkeys). No afectan a HotSlot y se pueden ignorar.

Si en depuración ves textos raros capturados "desde Xcode", es porque el portapapeles tenía texto de la consola de Xcode. Copiá en Notes, Cursor, Safari, etc. con esa app al frente.

## Desarrollo

```bash
# Generar proyecto Xcode (requiere XcodeGen)
brew install xcodegen
xcodegen generate

# Abrir en Xcode
open HotSlot.xcodeproj
```

## ¿Dónde está la app?

- **Al correr desde Xcode:** no aparece en `/Applications`; vive en DerivedData. Buscá el icono en la **menu bar** (barra superior de macOS, arriba a la derecha).
- **Clic izquierdo** en el icono → abre/cierra el panel.
- **Clic derecho** en el icono → Ajustes / Salir.

## Atajos por defecto

| Acción | Atajo |
|--------|-------|
| Abrir/cerrar panel | ⌘⇧V |
| Pegar slot 1–5 | ⌘⇧A, S, D, Q, W |
| Guardar en slot 1–5 | ⌘⌃A, S, D, Q, W |

Si un atajo no funciona: **Ajustes → Atajos → Restaurar atajos por defecto** o grabá uno nuevo.

## Permisos

HotSlot pide **Accesibilidad** para simular ⌘V/⌘C en la app donde estabas (pegado automático y guardar selección en slots). Configuralo en **Ajustes → Permisos** o en el onboarding.

## Descarga pública (fuera de Mac App Store)

La versión completa se distribuye con **Developer ID + notarización** (no Mac App Store).

- [Landing / descarga](https://hotslot-app-docs.vercel.app/)
- [Política de privacidad](https://hotslot-app-docs.vercel.app/privacy.html)
- Script: `./scripts/release-direct.sh` · Cambios por versión: `CHANGELOG.md`

### Release (mantenedor)

Certificado **Developer ID Application** en el llavero. El script autodetecta el certificado si no pasás `DEVELOPER_ID`.

```bash
cp scripts/release.env.example scripts/release.env.local
# Editá release.env.local (o usá NOTARY_KEYCHAIN_PROFILE — ver el ejemplo)
brew install create-dmg   # opcional, para .dmg
./scripts/release-direct.sh
# Subir: gh release upload vX.Y.Z build/release/Slots-X.Y.Z.dmg build/release/SHA256.txt
```

Las variables en `release.env.local` se cargan solas. **Recomendado:** guardar la app-specific password en el Llavero con `xcrun notarytool store-credentials` y poner solo `NOTARY_KEYCHAIN_PROFILE="Slots-Notary"` en el archivo local.

**Sparkle (actualizaciones in-app):** una vez por máquina de release, generar claves con el binario `generate_keys` del paquete Sparkle y añadir `SUPublicEDKey` a `Info.plist`. Tras el `.dmg`, actualizar `docs/appcast.xml` con `generate_appcast` y commitear. Feed: `SUFeedURL` en Info.plist.

**Docs web (Vercel):** repo `docs/` → proyecto [hotslot-app-docs](https://vercel.com/gianpetriis-projects/hotslot-app-docs), root `docs`; push a `main` o `cd docs && npx vercel --prod`.

Bundle ID: `com.hotslot.app` · Sin recolección de datos

## Créditos

[Reporte iconos creados por Magnific - Flaticon](https://www.flaticon.es/iconos-gratis/reporte)

## Scripts

| Script | Uso |
|--------|-----|
| `release-direct.sh` | Archive, export Developer ID, notarize, staple, `.dmg` |
| `deploy-docs-vercel.sh` | Deploy manual de `docs/` |
| `seed_screenshot_demo.py` | Datos demo para capturas |

## Estructura

```
HotSlot/
├── App/           # Entry point, AppDelegate, AppState
├── Models/        # ClipItem, Slot, AppSettings
├── Services/      # Clipboard, Slots, Hotkeys, Paste
├── UI/            # Panel, Settings, StatusBar
└── Utilities/     # Pasteboard, AppSupport
```

Roadmap: `BACKLOG.md`
