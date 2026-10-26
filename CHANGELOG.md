# Changelog

## [0.18.1] — 2026-10-26

### UX

- Al pegar sin Accesibilidad: **diálogo nativo del sistema** primero (sin abrir Ajustes automáticamente).
- Aviso único si el ⌘ no cabe en la barra de menú; `autosaveName` en el ítem.

### Producto (base)

- **Trial 90 días** desde primera instalación; después solo **slot 1** sin licencia.
- Activación de clave en Ajustes; `docs/purchase.html` y `docs/MONETIZATION.md`.
- Script de release: `release.env.local`, perfil `notarytool` en Llavero.

## [0.18.0] — 2026-10-25

### Marca y UX

- Nombre visible **Slots** (Finder, UI, web). Bundle ID interno sin cambios (`com.hotslot.app`).
- Icono **⌘** gris / vidrio en Dock; barra de menú con SF Symbol template.
- Landing **Slots** (descarga `Slots-0.18.0.dmg`, favicon, copy slots-first).
- Atajo del panel editable desde el **badge en la barra de búsqueda** (y en Ajustes → Atajos).
- Dos badges por slot (pegar + guardar); ancho fijo para que el popover no salte al grabar.

### Correcciones

- **Esc** cierra el panel con la misma animación que clic fuera.
- Atajos globales estables tras grabar (`onKeyUp` + `reloadFromStorage` sin carreras).
- Doble clic en **Aplicaciones** o reabrir la app muestra el panel (app de barra de menú).
- Acento de UI gris (ya no azul del icono viejo).
- Accesibilidad: enlace a Ajustes del Sistema más fiable.

## [0.17.0] — 2026-10-25

### Mejoras

- Un solo flujo de **Ajustes** (sin ventana duplicada de SwiftUI); ventana por encima del panel.
- Al cerrar Ajustes, el panel **solo se reabre** si estaba abierto antes.
- **Atajos desde el panel:** clic en el badge del slot → editar pegar/guardar.
- Atajos aplicados al vuelo al grabarlos (sin relanzar la app).
- **Menu bar:** icono `clipboard.fill` más visible.
- **Sparkle** integrado (menú “Buscar actualizaciones…”); appcast y clave pública pendientes en el primer release con updates.

## [0.16.0] — 2026-10-08

### Distribución directa (fuera de Mac App Store)

- Pegado automático restaurado con **Accesibilidad + CGEvent** (comportamiento validado en v0.15.0).
- Mejor detección de app destino al abrir el panel (`captureForUpcomingPaste`).
- Panel no roba foco al abrirse (`orderFrontRegardless`).
- Documentación de release: `docs/DIRECT_DOWNLOAD.md`, script `scripts/release-direct.sh`.

### Removido

- Experimento v0.15.1 (System Events / Automatización sin Accesibilidad) — no cumplía la UX esperada.

## [0.15.0] — 2026-10

- Onboarding, sandbox, preparación App Store (build rechazado por Accesibilidad en revisión).

## Versiones anteriores

Ver tabla en [README.md](README.md).
