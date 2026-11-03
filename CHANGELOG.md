# Changelog

## [0.20.0] — 2026-11-03

### Panel UX (handoff + mejoras Gianluca)

- Historial: pin al hover (sin fondo); peek de imagen y expansión de texto largo.
- Slots: título abajo, renombrar inline, cruz vaciar a la izquierda, contenido real en card, imagen recortada al marco.
- Atajos: chip contextual guardar/pegar; popover compacto de grabación.
- Bibliotecas: reorden por drag, tacho al arrastrar, eliminar con confirmación; fondos de slot (handoff + degradé naranja).
- Apertura del panel más rápida; cabecera alineada; modales overlay (eliminar biblioteca).

### Otros

- Notch aviso en AppKit; menú barra y TCC dev (copiar a Aplicaciones); guía `docs/PRUEBA-MAC-REDISENO.md` y `docs/DECISIONES-UX-PANEL.md`.

## [0.19.0] — 2026-11-02

### Rediseño macOS (handoff Dante)

- Panel principal alineado a `Main`: grilla 3×2, cabecera, historial, footer, vidrio y tokens Inter Tight.
- Icono de menú desde marca Slots; fixture «Cargar ejemplo» coherente con el mock.
- Modales del panel vía overlay (nueva biblioteca y elegir slot al guardar); corrige `.sheet` que no abría en `NSPanel`.

### Docs

- `docs/DESVIOS-DISENO-DANTE.md` para validación con diseño.

## [0.18.4] — 2026-11-01

### UX

- Panel se cierra al abrir Ajustes/Licencia; misma posición diagonal; vuelve al cerrar Ajustes.
- Ajustes flotante sin ocultarse al usar otra app o la barra de menú; barra de menú no cierra el panel con Ajustes abiertos.
- Fondo del panel ignora clics en la barra de menú; scroll a Licencia sin mover la ventana.

### Accesibilidad

- TCC: `kCFBooleanTrue`, ventana principal, reintento de posición; diagnóstico en Permisos.

## [0.18.3] — 2026-11-01

### UX

- Ajustes en ventana normal (no flota sobre otras apps); scroll a Licencia desde el panel.
- Accesibilidad: activación más fiable antes del aviso TCC (ventana clave + `.regular`).

## [0.18.2] — 2026-11-01

### UX

- Onboarding centrado, fondo no bloqueante, se oculta al cambiar de app.
- Accesibilidad unificada (onboarding + Ajustes); menú barra: Licencia / Comprar; panel ⋯ Salir.
- Semilla del clip actual al instalar; guía barra de menú.

### Producto

- Activación de licencia **Lemon Squeezy** (UUID); checkout en `purchase.html`.

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
