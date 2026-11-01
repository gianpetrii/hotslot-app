# Desvíos sobre el handoff — revisión Dante

Lista **corta** de diferencias entre el handoff (`Main.png`, `Main.html`, `flujos.md`) y el build macOS actual. Sirve para que Dante valide, corrija o dé OK antes del build de usabilidad.

**Referencia de diseño:** carpeta handoff en Drive → `docs/HANDOFF-README.md`  
**Prueba local:** `docs/PRUEBA-MAC-REDISENO.md`  
**Acuerdos producto (no diseño visual):** `docs/DECISIONES-REDISENO.md`

**Estados:** `OK Dante` · `Pendiente` · `A revisar en prueba`

---

## Ya alineado (nov 2026)

Panel 1060×664, grilla 3×2 (slot 1 alto), cabecera con buscador pill + ⌘F + cerrar, historial 330px, footer pills + Guardar portapapeles con ›, tokens Inter Tight / colores `SlotsTheme`, icono de menú desde marca, gaps 24 entre bloques.

---

## Desvíos o mejoras a validar

| # | Handoff | Qué hicimos | Por qué | Estado |
|---|---------|-------------|---------|--------|
| 1 | Pista «Clic para pegar…» debajo del panel en el mock | Misma pista **debajo de la tarjeta de vidrio** (ventana un poco más alta) | Separar hint del contenido; no tapa pills | Pendiente |
| 2 | Botón **filtros** (sliders) | Abre **Ajustes** (no hay UI de filtros aún) | Reutilizar control hasta definir filtros | Pendiente |
| 3 | Buscador sin menú ⋯ | Tour / licencia / salir solo desde **Ajustes** y menú bar | Menos ruido en cabecera | Pendiente |
| 4 | Card: un chip de **pegar** | Igual en grilla; **guardar** se edita en popover del chip o menú contextual | Handoff muestra un chip; guardar sigue existiendo | OK alineado |
| 5 | Historial sin pin visible | **Fijar** solo en clic derecho (comportamiento previo de la app) | No pierde función; visual más limpio | Pendiente |
| 6 | Hover / peek en slots | Popover al pasar el mouse (delay ~0,4 s) | Heredado; no está en el mock estático | A revisar en prueba |
| 7 | Filas historial expanden texto largo | En panel usamos filas **tipo handoff**; expand al hover en otros contextos | Legibilidad vs densidad | A revisar en prueba |
| 8 | Slot 1 del mock = **flyer imagen** | Fixture «Cargar ejemplo»: slot 1 **link** (Behance); sin imagen demo embebida | Falta asset de flyer en fixture | Pendiente |
| 9 | Apertura panel: escala + fade (~220 ms) | Animación **unfold** (cuadrado → ancho → alto) legacy | Flujo dinámico aún no retocado | A revisar en prueba |
| 10 | Vidrio / sombra pixel-perfect | Aproximación SwiftUI (`vidrioTinte` + blur) | Limitación material nativo | Pendiente fino |

---

## Cómo actualizar este archivo

Cuando cambiemos algo **a propósito** sobre el handoff (UX o funcionalidad), agregar una fila con motivo claro. Cuando Dante responda, cambiar **Estado** a `OK Dante` o anotar su alternativa en la misma fila.

Commits recientes de alineación visual: `db99cfe`, `34de790`, `e3a9490` (rama `main`).
