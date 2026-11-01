# Decisiones — rediseño Slots (nov 2026)

Acuerdos entre Gianluca y desarrollo tras Etapa 0 y el handoff de Dante (descarga externa: `docs/HANDOFF-README.md`).

## Alcance inmediato

- **Solo macOS** hasta validar el build de usabilidad en Mac. **iOS (Etapa 2 del prompt) queda en pausa**; no crear target iPhone todavía.
- Objetivo del tramo: flujos **macOS 00–10** + aviso notch + provisorios nativos (`flujos.md`), más requisitos de `prueba-de-usabilidad.md` (datos ejemplo, eventos, humo).

## Monetización (Lemon, trial, compra)

- **Sección Licencia visible** en Ajustes y menús (trial + compra siguen como hoy).
- **Enfoque de desarrollo:** no retomar cambios de gating, checkout ni mensajes de compra hasta cerrar las etapas del rediseño macOS; el código (`Entitlements`, `LemonLicenseService`, `purchase.html`) se mantiene.
- Ver BACKLOG › monetización.

## Accesibilidad (TCC)

- **Producto:** el aviso del sistema debe volver a funcionar; activación manual con **+** no es aceptable a largo plazo (P0 en BACKLOG).
- **Prueba de usabilidad:** si el aviso sigue fallando, documentar workaround en guion del moderador; seguir investigando en paralelo al rediseño.

## Atajos por defecto

- Implementar **⌘⇧ A · S · D · Q · W** como en diseño.
- Si **⌘⇧Q** choca con “Cerrar sesión” de macOS o no se registra de forma fiable, registrar el conflicto en Ajustes y avisar a Dante (decisión 1 del handoff).

## iOS (cuando retomemos)

- **Mismo repo Git**, no otro proyecto: en Xcode se agregaría un **target** iOS (otra app dentro del `.xcodeproj`). No implica otro repositorio.
- Pasteboard en pantalla 01: opciones simplificadas —
  - **A)** Al abrir la app, no leer el portapapeles; mostrar “Tenés algo copiado” y leer solo al tocar “Guardar como slot”.
  - **B)** Leer al abrir y aceptar el aviso de iOS “pegar desde…”.
  - **Recomendación del handoff:** A para la primera vez. Decidir con Dante al arrancar iOS.

## Implementación macOS (orden para el agente)

1. **Fundaciones** — tokens, fuentes, ícono, modelo `Library` / `Slot` / `HistoryItem`, persistencia, fixture, registro de eventos.
2. **Núcleo** — notch, pegar/guardar con foco, historial (tipos ocultos), atajos.
3. **Pantallas** — arranque 00, onboarding 01–03, panel 04–08, ajustes 10, provisorios.
4. **Build de prueba** — humo, versión visible, DMG; TestFlight cuando exista iOS.

Reemplazo **incremental** del panel actual (no big-bang en un solo PR): tokens → componentes → panel nuevo → retirar `HotSlotDesign` viejo.

## Referencia de diseño

- Fuente de verdad de comportamiento: `01-docs/flujos.md` dentro del zip del handoff.
- Medidas y copy: HTML en `05-flujos/html/` y `02-diseno/html-referencia/`.
- Tokens Swift del handoff → `HotSlot/Design/SlotsTheme.swift`.
- **Desvíos intencionales sobre el mock (para validar con Dante):** `docs/DESVIOS-DISENO-DANTE.md`.
