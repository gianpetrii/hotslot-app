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
| Pegar slot 1–5 | ⌘⇧1 … ⌘⇧5 |
| Guardar en slot 1–5 | ⌘⌥1 … ⌘⌥5 |

Si un atajo no funciona: **Ajustes → Atajos → Restaurar atajos por defecto** o grabá uno nuevo.

## Permisos

HotSlot usa **Automatización** (System Events) para pegar automáticamente con ⌘V simulado. Si el permiso no está concedido, copia al portapapeles y muestra un aviso.

## Mac App Store

- Sandbox habilitado
- Sin recolección de datos
- Bundle ID: `com.hotslot.app`

## Estructura

```
HotSlot/
├── App/           # Entry point, AppDelegate, AppState
├── Models/        # ClipItem, Slot, AppSettings
├── Services/      # Clipboard, Slots, Hotkeys, Paste
├── UI/            # Panel, Settings, StatusBar
└── Utilities/     # Pasteboard, AppSupport
```
