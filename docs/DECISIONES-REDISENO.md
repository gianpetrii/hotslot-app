# Decisiones — rediseño Slots (nov 2026)

Acuerdos entre Gianluca y desarrollo tras Etapa 0 y el handoff de Dante (descarga externa: `docs/HANDOFF-README.md`).

## Alcance inmediato

- **Solo macOS** hasta validar el build de usabilidad en Mac. **iOS (Etapa 2 del prompt) queda en pausa**; no crear target iPhone todavía.
- Objetivo del tramo: flujos **macOS 00–10** + aviso notch + provisorios nativos (`flujos.md`), más requisitos de `prueba-de-usabilidad.md` (datos ejemplo, eventos, humo).

## Monetización (Lemon, trial, compra)

- **Sección Licencia visible** en Ajustes y menús (trial + compra siguen como hoy).
- **Enfoque de desarrollo:** no retomar gating, checkout ni copy de compra hasta cerrar el rediseño macOS; el código (`Entitlements.swift`, `LemonLicenseService`, `docs/purchase.html`) se mantiene.
- **Modelo acordado:** 30 días prueba completa → después solo slot 1 sin licencia; pago único **USD 10** (Lemon) → clave en Ajustes → General → Licencia. Canal fuera de MAS (Accesibilidad). Reactivar gating: **BACKLOG** › post-usabilidad.

## Accesibilidad (TCC) y sandbox

- **Sin App Sandbox** (nov 2026): con sandbox, macOS bloquea el aviso de Accesibilidad y el pegado con ⌘V sintético. Sandbox solo es obligatorio en Mac App Store, que ya rechazó la app por Accesibilidad; la distribución es DMG Developer ID notarizado.
- Si algún día se vuelve a Mac App Store, haría falta otra estrategia de pegado (p. ej. copiar y que el usuario pegue con ⌘V).
- Al pasar a sin sandbox, la app copia una vez datos y preferencias desde `~/Library/Containers/com.hotslot.app`.

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
- Validación de diseño con Dante: solo lo que Gianluca cargue en `docs/REVISION-PANEL-PARA-DANTE.md`.
