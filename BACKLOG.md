# HotSlot — Backlog

Prioridad: **P0** urgente · **P1** importante · **P2** mejora · **P3** futuro

Estado: `[ ]` pendiente · `[~]` en progreso · `[x]` hecho

---

## Crítico / Funcionalidad

| Estado | Pri | Tarea |
|--------|-----|-------|
| [x] | P0 | Fix pegado al clic en historial (Button + paste tras cerrar panel) |
| [x] | P0 | Fix ventana de Ajustes (hotkeys, slots, general) |
| [x] | P0 | Quitar highlight automático del ítem más reciente |
| [x] | P0 | Pegado: firma Apple Development + CGEvent (TCC ad-hoc invalidaba Accesibilidad) |
| [x] | P0 | Grabador de atajos: app agent + `.regular` al abrir Ajustes (el recorder sí graba) |
| [x] | P0 | Atajos grabados no aplican hasta relanzar (re-registrar al cerrar Ajustes) |
| [ ] | P1 | Confiabilidad del paste — reintentos y mejor feedback |

## UI / Panel

| Estado | Pri | Tarea |
|--------|-----|-------|
| [x] | P0 | Quitar botón de copiar a la derecha en filas del historial |
| [x] | P0 | Agregar pin para fijar ítems arriba del historial |
| [x] | P0 | Restaurar título "Historial" + separador entre Slots e Historial |
| [x] | P0 | Animar cambios del listado al escribir en el buscador |
| [x] | P1 | Reordenar historial con drag & drop |
| [x] | P1 | Filas más útiles: imagen grande, texto sin ícono, fecha de copiado, pin cuadrado |
| [x] | P1 | Layout dos columnas: buscador arriba, slots a la izquierda, historial a la derecha |
| [x] | P0 | Drag de slot arrastra el panel (`isMovableByWindowBackground`); el drop no llega |
| [x] | P0 | Overlay en slot: atajo de pegar + cruz encima del contenido (también si está vacío) |
| [x] | P2 | Cruz de vaciar al mismo tamaño visual que el badge de atajo (no más grande) |
| [x] | P1 | Arrastrar un ítem del historial a un slot para guardarlo ahí |
| [ ] | P1 | Ver mejor el contenido de un slot (peek al hover; no copiar el expand de filas) |
| [ ] | P1 | Sonidos por acción (éxito vs no se pudo pegar vs guardado vs vacío) |
| [ ] | P1 | Reordenar ítems **pinneados** con drag & drop (orden persistente entre pines) |
| [ ] | P2 | Metadata en español ("Imagen PNG" en vez de "PNG image") |
| [ ] | P2 | Sección visual separada para ítems pinneados vs recientes |

## Ajustes

| Estado | Pri | Tarea |
|--------|-----|-------|
| [ ] | P1 | Animar apertura/cierre de Ajustes (mismo lenguaje que el panel) |
| [ ] | P1 | Panel principal oculto mientras Ajustes está abierto (ya se oculta; no reabrir hasta cerrar) |

## Animaciones

| Estado | Pri | Tarea |
|--------|-----|-------|
| [x] | P1 | Animaciones de apertura/cierre más notorias (spring + slide) |
| [x] | P0 | Unfold de apertura (clip fijo; no redimensionar la ventana) |
| [ ] | P2 | Animación stagger al abrir (filas entran una a una) |
| [ ] | P3 | Grabar referencia del Clipboard nativo y afinar timing |

## Otros

| Estado | Pri | Tarea |
|--------|-----|-------|
| [ ] | P2 | Detectar / avisar conflictos de atajos (no auto-cambiar el default) |
| [ ] | P2 | Modo depuración clipboard más pulido |
| [ ] | P3 | Localización ES/EN completa |
| [ ] | P1 | Ícono de app: `docs/portapapeles.png` (Magnific / Flaticon) → AppIcon + menu bar |
| [ ] | P1 | Archive + TestFlight |

---

## Siguiente oleada (orden de implementación)

1. **P0 — Drag de slots vs mover el panel.** ~~Hecho.~~
2. **P0 — Overlay de slot.** ~~Hecho.~~
3. **P0 — Atajos en caliente.** ~~Hecho: al cerrar Ajustes se `removeAllHandlers` + `registerAll` + `enable`.~~
4. **P1 — Historial → slot.** ~~Hecho: drop de un clip sobre un slot lo guarda (reemplaza). El swap entre slots se mantiene.~~
5. **P1 — Peek de slot.** Al hover (con dwell), mostrar con claridad imagen/texto sin reventar la columna de 176 px.
6. **P1 — Sonidos.** Feedback acústico distinto según el resultado (pegar ok ≠ no había dónde pegar ≠ slot vacío ≠ guardado). El toggle de Ajustes es el interruptor maestro.
7. **P1 — Ícono.** Partir de `docs/portapapeles.png` (512×512). Dock/App Icon con márgenes estilo macOS; menu bar en template (no el PNG a color). Atribución ya está en Ajustes → General.
8. **P1 — Ajustes.** Fade/unfold similar al panel; el popup de HotSlot permanece cerrado hasta que se cierra Ajustes.

**Más tarde:** orden persistente de pines.

---

## Notas de diseño

### Layout dos columnas (hecho)

Panel 572×520: buscador a todo el ancho, slots en columna izquierda (~176 px), historial a la derecha.

### Reordenar pines y slots

- **Pinnes (pendiente):** el drag del historial mueve el array, pero al copiar o (des)fijar el pin vuelve arriba.
- **Slots:** `swapContents` intercambia contenido. El atajo sigue atado al número. El panel ya no se mueve al arrastrar un slot.
- **Historial → slot:** hold en la fila (no el pin) arrastra; drop usa `com.hotslot.panel-drag` y el id del clip. El + verde es copiar al slot.

### Overlay: cruz vs atajo

La cruz no debe ser más grande que el badge. ~~Hecho: overlay 22×22, mismo alto que el badge compacto.~~

### Peek de contenido en slots

La columna es fija (~176 px, cinco tarjetas). Expandir como en el historial (más alto, más líneas) empuja al resto o recorta. No copiar ese patrón.

Dirección: **peek**, no grow. Mismo dwell que las filas (~0.42 s). Preview flotante (popover o lamina sobre el panel): imagen más grande, texto con más líneas. El slot en la grilla no cambia de tamaño. Clic sigue pegando; el peek es solo lectura.

### Conflictos de atajos

No auto-robar ni cambiar el default si otra app ya lo usa. Avisar y dejar que el usuario grabe otro. ⌘⇧1…5 se mantienen como default de producto a propósito.

### Ícono (pendiente)

Fuente: [portapapeles / Magnific — Flaticon](https://www.flaticon.es/icono-gratis/portapapeles_3286169), archivo `docs/portapapeles.png` (512×512 RGBA).

- **Dock / Finder / About:** generar `AppIcon.appiconset` (hasta 1024). No full-bleed: padding tipo macOS, fondo que lea nativo (no el PNG crudo sobre transparente en el grid).
- **Menu bar:** silueta template 18 pt (`isTemplate = true`), no el glifo relleno a color. Hoy es `doc.on.clipboard`.
- **Licencia:** atribución visible en Ajustes → General, pie de «Acerca de», y en el README. Texto requerido: “Reporte iconos creados por Magnific - Flaticon” → https://www.flaticon.es/iconos-gratis/reporte

### Sonidos (pendiente)

Hoy solo suena `Pop` si el pegado automático llega a enviar ⌘V. Falta un mapa:

- **Pegado ok** — `Pop` (ya está).
- **No había app/campo donde pegar** (solo copió) — más grave, p. ej. `Basso`.
- **Sin Accesibilidad / ⌘V no salió** — `Basso`.
- **Slot vacío** — `Funk`.
- **Guardado en slot** (atajo, drop, menú) — `Tink`.
- **Vaciar slot / errores menores** — opcional y más suave.

El toggle «Sonido al pegar» pasa a ser el maestro de estos avisos, no un segundo switch. No sonar en hover ni en peek.
