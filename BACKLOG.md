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
| [x] | P0 | Revertir paste al flujo original (sin pre-check que abría Ajustes) |
| [x] | P0 | Grabador de atajos (NSWindow + desactivar globales en Ajustes) |
| [ ] | P2 | Animación escalonada buscador → cuerpo (dejado para después) |
| [ ] | P1 | Confiabilidad del paste — reintentos y mejor feedback |

## UI / Panel

| Estado | Pri | Tarea |
|--------|-----|-------|
| [x] | P0 | Quitar botón de copiar a la derecha en filas del historial |
| [x] | P0 | Agregar pin para fijar ítems arriba del historial |
| [x] | P0 | Restaurar título "Historial" + separador entre Slots e Historial |
| [x] | P0 | Animar cambios del listado al escribir en el buscador |
| [x] | P1 | Reordenar historial con drag & drop |
| [ ] | P1 | **Layout dos columnas**: slots en columna izquierda, buscador + historial a la derecha |
| [ ] | P2 | Metadata en español ("Imagen PNG" en vez de "PNG image") |
| [ ] | P2 | Preview más grande de imágenes en filas |
| [ ] | P2 | Sección visual separada para ítems pinneados vs recientes |

## Animaciones

| Estado | Pri | Tarea |
|--------|-----|-------|
| [x] | P1 | Animaciones de apertura/cierre más notorias (spring + slide) |
| [x] | P2 | Apertura escalonada: buscador primero, cuerpo se estira hacia abajo |
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

### Layout dos columnas (pendiente — P1)

Panel ~560×520 px: slots verticales a la izquierda, historial completo a la derecha.

**Recomendación:** implementar después de validar pegado + ajustes + pin.
