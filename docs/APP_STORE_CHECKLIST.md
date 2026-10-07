# Checklist App Store Connect — HotSlot

## Antes de subir

- [x] Cuenta Apple Developer activa
- [x] Bundle ID `com.hotslot.app` registrado con App Sandbox
- [x] Certificado "Mac App Distribution" configurado en Xcode
- [x] App icon 1024×1024 (sin canal alpha) en Assets.xcassets
- [x] Screenshots macOS → `docs/app-store-screenshots/1280x800/`
- [x] Versión **0.15.0 (16)** en project.yml

## App Store Connect

- [x] Crear app en App Store Connect (macOS)
- [x] Descripción, keywords, categoría Productivity
- [x] Privacy Policy URL: https://hotslot-app-docs.vercel.app/privacy.html
- [x] App Privacy: **No data collected**
- [x] Export compliance: sin cifrado propio → No
- [x] Age rating completado (4+)
- [ ] Notas para revisión:
  - App de clipboard local, sin red
  - Usa Automatización (System Events) solo para simular ⌘V al pegar

## Permisos explicados al usuario

- **Automatización (Apple Events)**: pegado ⌘V y guardar selección ⌘C — macOS pide permiso por app destino
- **No usa Accesibilidad** (requisito App Store 2.4.5)
- **Atajos globales**: Carbon / KeyboardShortcuts (no Input Monitoring)

## TestFlight / Archive

- [x] Build **0.15.0 (16)** subida a App Store Connect
- [~] Ficha macOS + capturas → enviar a revisión
- [ ] Probar build en Safari, Notes, Chrome (TestFlight o instalación local)
