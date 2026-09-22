# HotSlot

Clipboard manager nativo para macOS con historial, slots fijos y atajos globales.

## Requisitos

- macOS 14.0+
- Xcode 15+

## Desarrollo

```bash
# Generar proyecto Xcode (requiere XcodeGen)
brew install xcodegen
xcodegen generate

# Abrir en Xcode
open HotSlot.xcodeproj
```

## Atajos por defecto

| Acción | Atajo |
|--------|-------|
| Abrir/cerrar panel | ⌘⇧V |
| Pegar slot 1–5 | ⌘⇧1 … ⌘⇧5 |
| Guardar en slot 1–5 | ⌘⌥1 … ⌘⌥5 |

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
