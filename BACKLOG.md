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
| [ ] | P0 | Atajos grabados no aplican hasta relanzar (re-registrar al cerrar Ajustes) |
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
| [ ] | P0 | Overlay en slot: atajo de pegar + cruz encima del contenido (también si está vacío) |
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
| [ ] | P1 | Ícono de app 1024×1024 |
| [ ] | P1 | Archive + TestFlight |

---

## Siguiente oleada (orden de implementación)

1. **P0 — Drag de slots vs mover el panel.** ~~Hecho: el panel se mueve desde el buscador; las tarjetas ya no arrastran la ventana.~~
2. **P0 — Overlay de slot.** Atajo de pegar (siempre, también vacío) y cruz (si hay contenido, en hover) encima de la imagen/texto, no en una fila que coma altura.
3. **P0 — Atajos en caliente.** `registerAll()` corre una vez al boot; al grabar se persiste pero el listener global no se refresca hasta relanzar. Al cerrar Ajustes hay que re-habilitar y re-bindear.
4. **P1 — Ajustes.** Fade/unfold similar al panel; el popup de HotSlot permanece cerrado hasta que se cierra Ajustes.

---

## Notas de diseño

### Layout dos columnas (hecho)

Panel 572×520: buscador a todo el ancho, slots en columna izquierda (~176 px), historial a la derecha.

### Reordenar pines y slots

- **Pinnes (pendiente):** el drag del historial mueve el array, pero al copiar o (des)fijar el pin vuelve arriba.
- **Slots:** `swapContents` intercambia contenido. El atajo sigue atado al número. El panel ya no se mueve al arrastrar un slot.

### Conflictos de atajos

No auto-robar ni cambiar el default si otra app ya lo usa. Avisar y dejar que el usuario grabe otro. ⌘⇧1…5 se mantienen como default de producto a propósito.
