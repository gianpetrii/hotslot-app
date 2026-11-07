# HotSlot — Backlog

Prioridad: **P0** urgente · **P1** importante · **P2** mejora · **P3** futuro

Estado: `[ ]` pendiente · `[~]` en progreso · `[x]` hecho

## Decisiones de producto (alineación Oct 2025 — actualizado)

- **Monetización:** **90 días** de prueba → **USD 10** pago único (Lemon, `Entitlements.swift`). **UI de licencia visible**; no retomar cambios de gating/compra hasta cerrar el rediseño (ver `docs/DECISIONES-REDISENO.md`).
- **Mensaje público:** **slots fijos** como lead; historial + búsqueda como complemento.
- **Distribución:** DMG notarizado + GitHub Releases.
- **Rediseño (nov 2026):** handoff Dante **fuera del repo** — enlace en `docs/HANDOFF-README.md`; **solo macOS primero**, iOS después.
- **Fuera del build de usabilidad:** Sync, compras visibles, modo oscuro, iPad.

---

## Crítico / Funcionalidad

| Estado | Pri | Tarea |
|--------|-----|-------|
| [x] | P0 | **Accesibilidad (TCC):** aviso del sistema funcionando en DMG (v0.21.0): sin App Sandbox y aviso traído al frente sobre las ventanas flotantes de Slots. Validado por Gianluca. |
| [x] | P0 | Fix pegado al clic en historial (Button + paste tras cerrar panel) |
| [x] | P0 | Fix ventana de Ajustes (hotkeys, slots, general) |
| [x] | P0 | Quitar highlight automático del ítem más reciente |
| [x] | P0 | Pegado: firma Apple Development + CGEvent (TCC ad-hoc invalidaba Accesibilidad) |
| [x] | P0 | Grabador de atajos: app agent + `.regular` al abrir Ajustes (el recorder sí graba) |
| [x] | P0 | Atajos grabados no aplican hasta relanzar (re-registrar al cerrar Ajustes) |
| [x] | P1 | Defaults de slots: pegar ⌘⇧A S D Q W y guardar ⌘⌃A S D Q W |
| [x] | P1 | Confiabilidad del paste — reintentos y mejor feedback |

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
| [x] | P1 | **Clic en slot/historial:** copiar al portapapeles (default) o pegar donde estaba el cursor (Ajustes). Atajos siguen pegando. Validado. |
| [ ] | P1 | **Archivos en slots e historial:** guardar y pegar files (PDF, zip, etc.), no solo texto e imagen |
| [x] | P1 | Ver mejor el contenido de un slot (peek al hover; no copiar el expand de filas) |
| [x] | P1 | Sonidos por acción (éxito vs no se pudo pegar vs guardado vs vacío) |
| [x] | P1 | Reordenar ítems **pinneados** con drag & drop (orden persistente entre pines) |
| [x] | P2 | Metadata en español ("Imagen PNG" en vez de "PNG image") |
| [ ] | P2 | Sección visual separada para ítems pinneados vs recientes — descartado: ya se entiende |

## Ajustes

| Estado | Pri | Tarea |
|--------|-----|-------|
| [x] | P1 | Animar apertura/cierre de Ajustes (mismo lenguaje que el panel) |
| [x] | P1 | Panel principal oculto mientras Ajustes está abierto; al cerrar se reabre el popup |

## Animaciones

| Estado | Pri | Tarea |
|--------|-----|-------|
| [x] | P1 | Animaciones de apertura/cierre más notorias (spring + slide) |
| [x] | P0 | Unfold de apertura (clip fijo; no redimensionar la ventana) |
| [ ] | P2 | Animación stagger al abrir (filas entran una a una) |
| [ ] | P2 | Limpiar `RichText/` (formato de textos) cuando el texto ya no está en historial ni en slots |
| [x] | P2 | Expand/collapse de filas: texto animado; imagen crece desde arriba sin el “bajón” |
| [x] | P2 | Onboarding de primera vez (tour saltables, repetible) |
| [ ] | P3 | Grabar referencia del Clipboard nativo y afinar timing |

## Rediseño Slots (handoff Dante · ver `docs/HANDOFF-README.md`)

Objetivo: **build de prueba de usabilidad en Mac**. Alcance y acuerdos: `docs/DECISIONES-REDISENO.md`. Lo que **Dante** debe validar explícitamente: `docs/REVISION-PANEL-PARA-DANTE.md` (solo ítems que cargue Gianluca).

| Estado | Etapa | Alcance (macOS primero) |
|--------|-------|-------------------------|
| [x] | **0** | Diagnóstico — OK nov 2026 |
| [x] | **1** | Tokens, fuentes, ícono, modelo Library/Slot/HistoryItem, fixture, eventos |
| [ ] | **2** | ~~iOS 00–13~~ **pausado** hasta validar Mac |
| [x] | **3** | Núcleo Mac: notch, historial oculto (concealed), sync workspace, atajos |
| [x] | **4** | Panel Mac handoff (header, bibliotecas, guardar portapapeles, onboarding 3, ajustes sidebar, arranque) |
| [~] | **5** | Humo Mac, versión, DMG, guía de prueba final |

## Landing web (handoff Dante · `docs/slots-landing/`)

Objetivo: **preventa + demo en vivo** alineada a marca Slots; la app sigue en GitHub Releases (`/releases/latest`).

| Estado | Pri | Tarea |
|--------|-----|-------|
| [x] | P1 | Publicar landing Dante como `docs/index.html` + favicon |
| [x] | P1 | Enlaces **Beta Mac** y **Privacidad** (`privacy.html`) en nav y pie |
| [ ] | P1 | **Cambio de idioma:** transición al pasar de español a inglés (y al revés), para que el reflow del layout no se sienta un salto. Primero de los P1, después de cerrar la oleada V |
| [ ] | P1 | **Barra del notch:** al pasar el mouse por el rectángulo negro de arriba al centro, baja una barra horizontal con los 5 slots en cuadrados iguales (estilo e info ya guardados). Las bibliotecas van debajo o al costado para cambiar de vista. Es el panel acostado, para ocupar menos espacio. En Macs sin notch, el mismo gesto sale desde el centro de la barra de menú. La landing ya lo promete («Pasás el mouse por el notch y ves tus slots»); la app solo tiene la píldora de confirmación |
| [ ] | P1 | **Formspree / waitlist:** pegar `WAITLIST_ENDPOINT` (ver `slots-landing/LEEME.md`) |
| [ ] | P2 | **og:image** 1200×630 para compartir en redes |
| [ ] | P2 | Validar promesas de lista (beta, preventa, mes gratis) con producto — LEEME §5 |
| [ ] | P2 | Deploy Vercel tras push; smoke ES/EN, móvil, formulario |
| [ ] | P3 | Video hero `VIDEO_SRC` cuando exista mp4 liviano |
| [ ] | P3 | Analytics (Plausible / Vercel) si pautan |

### Panel rediseño Mac (handoff)

| Estado | Pri | Tarea |
|--------|-----|-------|
| [x] | P2 | **Bibliotecas:** reorden drag + eliminar + renombrar (confirmación eliminar); dwell slot→pill |
| [~] | P2 | **Panel UX** — oleada nov 2026 (tabla «Panel UX — validación Gianluca» más abajo) |
| [ ] | P2 | **Grilla slots:** tamaños editables por slot (cuadrado vs alto) |

| Estado | Pri | Tarea post-usabilidad |
|--------|-----|------------------------|
| [ ] | P1 | **Reactivar monetización** (trial, Lemon, compra, gating slots 2–5) |

## Otros

| Estado | Pri | Tarea |
|--------|-----|-------|
| [x] | P2 | Detectar / avisar conflictos de atajos (no auto-cambiar el default) |
| [ ] | P2 | Modo depuración clipboard más pulido |
| [ ] | P3 | Localización ES/EN completa |
| [x] | P1 | Ícono de app: `docs/portapapeles.png` (Magnific / Flaticon) → AppIcon + menu bar |
| [x] | P1 | Distribución directa v0.16 (Developer ID, notarización, landing, GitHub Release) |

---

## Panel UX — validación Gianluca (nov 2026)

Probar en Mac (ideal: app en **Aplicaciones**). Marcar acá; **no** duplicar en otros `.md` salvo `REVISION-PANEL-PARA-DANTE.md` cuando toque Dante.

| Estado | ID | Tema |
|--------|-----|------|
| [x] | V2 | Animación al **cambiar biblioteca** |
| [x] | V3 | **Reorden:** fantasma en el lugar de origen, las pills se separan, al soltar queda ahí · **Tacho:** se agranda (oscuro + naranja), soltar → confirmación con «No volver a preguntar» (reactivable en Ajustes → General) |
| [x] | V4–V5 | **Historial:** saltos de línea visibles · 2 renglones cerrado, hasta 8 al expandir, solo expande si el texto quedó cortado · pin arriba a la derecha sin fondo (fondo blanco solo sobre imagen agrandada), fijado = contorno naranja |
| [ ] | V4b | **Pegar con estilos** (negrita, etc.) desde historial y slots; texto plano si la app no acepta formato. Probar con DMG |
| [x] | V6–V7 | **Chips:** cruz y atajo con la misma pastilla (arena en card clara, blanca sobre imagen o fondo oscuro). Al aparecer la cruz, «Slot N» se corre a la derecha |
| [x] | V8 | Texto blanco + velo arriba/abajo en degradé, imagen y fondo oscuro |
| [x] | V9–V10 | Lápiz junto al nombre de biblioteca / a la derecha en slots · transición al editar · Enter o clic fuera guarda (el clic no dispara la otra acción) · Escape cancela · slots vacíos se renombran y el nombre se conserva al vaciar |
| [x] | V11 | *(confirmado en pasada anterior)* |
| [x] | V12 | Oleada de panel cerrada. Queda afuera V4b (pegar con estilos), que se prueba con un DMG |
| [x] | V13 | **Hover:** la misma sombra cálida en slots con contenido, filas del historial, pills no seleccionadas y «+». Sin sombra en slots vacíos. Naranja sólido solo al soltar encima |
| [x] | V14 | **Clic:** el slot se llena de su propio color, sin texto, un instante antes de cerrar. En el historial solo cambia el fondo a papel y el texto sigue. Al reabrir queda limpio. La velocidad del cierre no cambia |
| [x] | V16 | **Fondos de slot:** predeterminado = papel. Vaciar muestra el estilo vacío pero recuerda el color y lo restaura al guardar. El paso entre vacío, color y contenido se funde. El color persiste al reabrir y al cambiar de biblioteca |
| [x] | V17 | **«+» de bibliotecas:** hover = solo sombra. Clic = pulso de escala que se ve aunque sea instantáneo, y después abre el formulario. Pills no seleccionadas validadas |
| [x] | V15 | **Aviso del notch:** píldora negra al copiar, guardar o pegar. Naranja solo si pide una acción (accesibilidad, slot vacío). La barra desplegable con los 5 slots queda en P1 |

**Dante (solo si Gianluca lo pide):** reorden de bibliotecas → `docs/REVISION-PANEL-PARA-DANTE.md`.

---

## QA Mac — humo antes de tag / DMG

| Qué | Xcode Run | App en `/Applications` |
|-----|-----------|-------------------------|
| Panel, bibliotecas, guardar, Ajustes | ✅ | ✅ |
| Splash naranja al abrir | ❌ | ✅ |
| TCC Accesibilidad / pegar en otra app | ⚠️ | ✅ recomendado |

**Rápido (~15 min):** ⌥ menú → **Cargar ejemplo** · onboarding (**Empezar de cero**) · ⌘⇧V panel · cambiar biblioteca · **Guardar portapapeles** (no requiere TCC) · drag historial → slot · smoke menú contextual slot · Ajustes tabs · menú bar **Ver todo**.

**P0 TCC:** sigue en tabla Crítico arriba. **Eventos moderador:** ⌥ menú → Exportar eventos.

---

## Oleada actual (feedback testers + producto)

| Estado | Pri | Tarea |
|--------|-----|-------|
| [~] | P1 | **Sparkle** — integrado; falta `SUPublicEDKey` + `generate_appcast` en cada release |
| [x] | P1 | **Ícono menu bar más visible** — `clipboard.fill` semibold 15 pt |
| [x] | P1 | **Editar atajos desde el panel** — clic en badge → popover pegar/guardar |
| [x] | P1 | **Un solo flujo de Ajustes** — escena SwiftUI vacía + ⌘,; ventana sobre el panel; panel solo se reabre si estaba abierto |
| [x] | P1 | **Badges de atajos en vivo** — `applyStoredShortcuts` + `shortcutEpoch` al cambiar atajo |
| [ ] | P2 | **Sonido al guardar** — documentar toggle “Sonidos de acciones”; opcional sonido distinto guardar vs pegar si confunden |
| [ ] | P3 | Atajo clicable extra en barra (además del icono) — evaluar si aporta o satura la menu bar |
| [ ] | P3 | “Slots libres” en UI tipo Dynamic Island — **no aplica en Mac**; en iPhone sería otro producto |
| [ ] | P1 | **Landing:** copy slots-first + enlace donación + créditos desarrolladores *(superseded por landing Dante; ver sección Landing web)* |
| [ ] | P1 | **Donación:** link en Ajustes → General / Acerca de (Ko-fi o similar) |
| [ ] | P1 | **Analytics:** contador descargas (GitHub) en web; Vercel Analytics en docs; ping anónimo in-app acordado en privacidad |

### Propuesta rápida (cómo resolver)

- **Sparkle:** integrar framework; `appcast.xml` en GitHub Releases o CDN; firmar updates con clave EdDSA; `SUFeedURL` en Info.plist; post-release: generar appcast en script junto al `.dmg`.
- **Ícono barra:** rediseñar `MenuBarIcon` (PDF/PNG template, trazo más bold); en código probar `NSStatusItem.variableLength` + padding; fallback SF Symbol `clipboard.fill` si el asset sigue tenue.
- **Atajos en panel:** badge del overlay ya muestra el atajo → hacerlo botón; `Popover` + recorder por `pasteSlotN` / `copyToSlotN`; validar conflictos con `ShortcutConflict` inline.
- **Ajustes / testers:** `HotSlotApp` sin escena `Settings` duplicada o redirigir a `SettingsWindowController`; `presentUtilityWindow` siempre; subir `window.level` de Ajustes > panel.

---

## Siguiente oleada (histórico — orden de implementación)

1. **P0 — Drag de slots vs mover el panel.** ~~Hecho.~~
2. **P0 — Overlay de slot.** ~~Hecho.~~
3. **P0 — Atajos en caliente.** ~~Hecho: al cerrar Ajustes se `removeAllHandlers` + `registerAll` + `enable`.~~
4. **P1 — Historial → slot.** ~~Hecho: drop de un clip sobre un slot lo guarda (reemplaza). El swap entre slots se mantiene.~~
5. **P1 — Peek de slot.** ~~Hecho: popover al dwell; historial in-place; texto del peek se achica al contenido.~~
6. **P1 — Sonidos.** ~~Hecho en v0.10.0: Boop al pegar; Bubble si no hay destino/slot vacío; Funky al guardar. El atajo de guardar toma la selección, no el último clip.~~
7. **P1 — Defaults A S D Q W.** ~~Hecho: pegar ⌘⇧A/S/D/Q/W y guardar ⌘⌃ iguales. Migración v4/v5 solo si el atajo era el de fábrica; si el usuario grabó otro, no se toca.~~
8. **P1 — Ajustes.** ~~Fade al abrir/cerrar; al cerrar se reabre el popup. Sin `close()` ni resize (ViewBridge/lldb).~~
9. **P1 — Ícono.** ~~Hecho: AppIcon con padding y fondo papel; menu bar template 18 pt. Atribución en Ajustes → General.~~
10. **P1 — Orden de pines.** ~~Hecho: el drag entre pines se guarda; copiar no manda el pin arriba.~~

**Más tarde:** Archive + TestFlight.

---

## Notas de diseño

### Layout dos columnas (hecho)

Panel 572×520: buscador a todo el ancho, slots en columna izquierda (~176 px), historial a la derecha.

### Reordenar pines y slots

- **Pinnes:** el drag reordena entre pines y se guarda. Copiar un pin no lo manda arriba. Un pin nuevo se agrega al final del bloque.
- **Slots:** `swapContents` intercambia contenido. El atajo sigue atado al número. El panel ya no se mueve al arrastrar un slot.
- **Historial → slot:** hold en la fila (no el pin) arrastra; drop usa `com.hotslot.panel-drag` y el id del clip. El + verde es copiar al slot.

### Overlay: cruz vs atajo

La cruz no debe ser más grande que el badge. ~~Hecho: overlay 22×22, mismo alto que el badge compacto.~~

### Peek de contenido en slots

La columna es fija (~176 px, cinco tarjetas). Expandir como en el historial (más alto, más líneas) empuja al resto o recorta. No copiar ese patrón.

Dirección: **peek**, no grow. ~~Hecho: popover al dwell, a la derecha. Historial sigue expandiendo in-place. Texto del peek se achica al contenido, con tope y scroll. Imagen tamaño fijo.~~

### Conflictos de atajos

No auto-robar ni cambiar el default si otra app ya lo usa. Avisar y dejar que el usuario grabe otro. Default de producto: ⌘⇧A/S/D/Q/W (pegar) y ⌘⌃ iguales (guardar). Quien tenía 1–5 o ⌘⌥ de fábrica pasa a esos; atajos personalizados se conservan.

### Ícono (hecho)

Fuente: [portapapeles / Magnific — Flaticon](https://www.flaticon.es/icono-gratis/portapapeles_3286169), archivo `docs/portapapeles.png` (512×512 RGBA).

- **Dock / Finder / About:** generar `AppIcon.appiconset` (hasta 1024). No full-bleed: padding tipo macOS, fondo que lea nativo (no el PNG crudo sobre transparente en el grid).
- **Menu bar:** silueta template 18 pt (`isTemplate = true`), no el glifo relleno a color. Hoy es `doc.on.clipboard`.
- **Licencia:** atribución visible en Ajustes → General, pie de «Acerca de», y en el README. Texto requerido: “Reporte iconos creados por Magnific - Flaticon” → https://www.flaticon.es/iconos-gratis/reporte

### Sonidos

- **Pegado ok** — Boop (`Tink.aiff`).
- **Error** (escritorio/Finder, sin destino, o slot vacío) — Bubble (`Pop.aiff`).
- **Guardado en slot** — Funky (`Funk.aiff`).
- Hover y peek no suenan. El toggle «Sonidos de acciones» los silencia todos.
