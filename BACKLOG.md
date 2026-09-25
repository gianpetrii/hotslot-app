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
| [~] | P0 | Grabador de atajos: app agent + `.regular` al abrir Ajustes (validar) |
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
| [ ] | P1 | Reordenar ítems **pinneados** con drag & drop (orden persistente entre pines) |
| [x] | P1 | Reordenar **slots** con drag & drop (el atajo sigue atado al número del slot) |
| [x] | P1 | Layout dos columnas: buscador arriba, slots a la izquierda, historial a la derecha |
| [ ] | P2 | Metadata en español ("Imagen PNG" en vez de "PNG image") |
| [ ] | P2 | Sección visual separada para ítems pinneados vs recientes |

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
| [ ] | P2 | Detectar conflictos de atajos con otras apps |
| [ ] | P2 | Modo depuración clipboard más pulido |
| [ ] | P3 | Localización ES/EN completa |
| [ ] | P1 | Ícono de app 1024×1024 |
| [ ] | P1 | Archive + TestFlight |

---

## Notas de diseño

### Layout dos columnas (hecho)

Panel 572×520: buscador a todo el ancho, slots en columna izquierda (~176 px), historial a la derecha.

### Reordenar pines y slots (pendiente — P1)

- **Pinnes:** el drag actual mueve el array entero, pero al copiar de nuevo o al (des)fijar el pin vuelve arriba. Hace falta un orden propio entre pinneados que sobreviva a esas operaciones.
- **Slots:** arrastrar intercambia contenido (y preview). El atajo ⌘⇧N sigue pegando el slot N, no “el que estaba en esa posición visual al grabar”.

