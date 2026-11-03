# Decisiones UX — panel macOS (Gianluca + socio)

Alineado a tokens `SlotsTheme` / handoff `Main.html`. Estado: **nov 2026**.

## Resumen de acuerdos

| Tema | Decisión | Estado |
|------|----------|--------|
| Flecha historial | Quitar; **pin** solo al **hover** (sin fondo, como la flecha) | Implementado |
| Atajos en slot | **Vacío → chip guardar (⌘⌃)** · **Con contenido → chip pegar (⌘⇧)** · Popover sigue editando **ambos** | Implementado |
| Contenido en slot | Mostrar **texto/link** en el cuerpo, no «Texto · N palabras» | Implementado |
| Imagen en slot | **Fill** dentro de la card | Implementado |
| Cruz vaciar | **Izquierda** en cabecera; el texto «Slot N» se corre al hover | Implementado |
| Renombrar slot | **Inline** abajo en la card; **Enter** o clic en la card confirma; **Esc** cancela | Implementado |
| Popover atajos | Estilo Slots (tipografía, colores, copy) | Implementado |
| Bibliotecas | **Drag** reorden (pill objetivo se desplaza) · **Tacho** al arrastrar · Eliminar (confirmación) | Parcial |
| Fondo de slot (paleta) | Default **handoff** (blanco / vacío rayado); opción **degradé naranja** (marca) | Implementado |
| Tamaño / forma de slots | Grilla editable (cuadrado vs alto) | **Pendiente** — requiere schema + UI layout (Epic B) |

---

## Epic A — Hecho en este tramo

### A1 Historial
- Pin en fila (panel handoff), **solo al hover** (también el clip más reciente); clic derecho «Fijar arriba» se mantiene.
- Hover ~0,4 s: **texto largo** expande en la fila; **imagen** abre peek (popover).
- Sin flecha `arrow.up.right` (no tenía acción).

### A2 Atajos visibles
- Un chip contextual evita ruido; el popover al clic en el chip muestra pegar + guardar.
- Alternativa descartada por ahora: dos chips siempre (handoff muestra uno).

### A3 Card de slot
- Cabecera: «Slot N» (se desplaza al hover) + vaciar a la **izquierda** + chip atajo.
- Título editable **abajo** (label); lápiz al hover, mismo tamaño que el título.
- Cuerpo: preview del contenido o placeholder vacío; imagen recortada al marco del slot.

### A4 Bibliotecas
- Reorden: arrastrar pill; la pill objetivo se **corre** ligeramente (preview de hueco).
- Eliminar: menú contextual o **soltar sobre el tacho** (visible al arrastrar una pill).
- **Ideas UX (pendiente):** arrastrar slot a pill → pausa → cambiar biblioteca → soltar en slot.

---

## Epic B — Pendiente (no olvidar)

### B1 Tamaños de slot en grilla
- Hoy: slot 1 = 2 filas, 2–5 cuadrados (fijo en `SlotGridView`).
- Objetivo: por slot, elegir **1×1** o **1×2** (vertical) dentro de la misma grilla 3×2.
- Necesita: `SlotLayoutPreference` en persistencia (workspace o slot), validación de solapamientos, mock Dante.

### B2 Más paleta / fondos
- Ampliar swatches si Dante entrega tabla en handoff.

### B3 Eliminar biblioteca (handoff Dante)
- Validar copy y si los slots deben moverse a otra biblioteca vs borrarse.

---

## Referencias

- Desvíos visuales: `docs/DESVIOS-DISENO-DANTE.md`
- Backlog operativo: `BACKLOG.md` › Panel UX
