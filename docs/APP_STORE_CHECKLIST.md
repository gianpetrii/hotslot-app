# Checklist App Store Connect — HotSlot

## Antes de subir

- [ ] Cuenta Apple Developer activa
- [ ] Bundle ID `com.hotslot.app` registrado con App Sandbox
- [ ] Certificado "Mac App Distribution" configurado en Xcode
- [ ] App icon 1024×1024 (sin canal alpha) en Assets.xcassets
- [ ] Screenshots macOS (mín. 1280×800)
- [ ] Versión y build number actualizados en project.yml

## App Store Connect

- [ ] Crear app en App Store Connect (macOS)
- [ ] Descripción, keywords, categoría Productivity
- [x] Privacy Policy URL: https://gianpetrii.github.io/hotslot-app/privacy.html
- [x] App Privacy: **No data collected**
- [ ] Export compliance: sin cifrado propio → No
- [ ] Age rating completado
- [ ] Notas para revisión:
  - App de clipboard local, sin red
  - Usa Automatización (System Events) solo para simular ⌘V al pegar

## Permisos explicados al usuario

- **Automatización**: pegar en la app activa
- **No** requiere Accesibilidad ni Input Monitoring (hotkeys vía Carbon)

## TestFlight

- [ ] Build subida con `xcodebuild archive` + `notarytool` / Xcode Organizer
- [ ] Prueba interna en Safari, Notes, Chrome, VS Code
- [ ] Verificar pegado con y sin permiso de Automatización
