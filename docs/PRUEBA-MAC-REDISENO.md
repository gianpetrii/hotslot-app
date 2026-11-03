# Prueba integrada — build rediseño macOS

Usar **al final** del tramo Etapa 4–5 (no hace falta validar cada commit). TCC Accesibilidad: anotar aparte si sigue sin listar la app.

## Cómo probar (Xcode vs Aplicaciones)

| Qué | Run en Xcode | App en `/Applications` (DMG o copiar `.app`) |
|-----|----------------|--------------------------------------------------|
| Panel, bibliotecas, guardar portapapeles, Ajustes, menús | ✅ Sí | ✅ Sí |
| Splash naranja al abrir | ❌ No (salvo que copies el `.app` a Aplicaciones) | ✅ Sí |
| Aviso TCC de Accesibilidad fiable | ⚠️ A veces no; path en DerivedData confunde | ✅ Recomendado |
| Pegar con atajo / historial que pega en otra app | ❌ Sin permiso TCC | ✅ Con permiso |

**Una sola vez para desbloquear 4–6 y TCC:** instalá la beta desde [GitHub Releases](https://github.com/gianpetrii/hotslot-app/releases/latest) **o** en Xcode → **Product → Show Build Folder in Finder** → `Products/Debug/Slots.app` → arrastrá a **Aplicaciones** y abrí **esa** copia (no hace falta un DMG nuevo por cada cambio; sí conviene reinstalar cuando cambie mucho el build).

**Paso 1 desde Xcode:** no tenés que “validar” splash. Con Run alcanza con: onboarding 3 pasos (⌥ clic menú → **Empezar de cero**) y que el panel abra. Splash = opcional cuando tengas la app en Aplicaciones.

## Antes

- **Datos de ejemplo:** ⌥ + **clic derecho** en el icono de la barra → **Cargar ejemplo**.
- **Onboarding otra vez:** ⌥ + **clic derecho** → **Empezar de cero**.
- **Icono barra oculto:** macOS recuerda si lo sacaste con ⌘+arrastrar; build reciente usa nuevo `autosaveName` v2. Fallback visible «S» si el asset falla.

Reset manual (si hace falta):

```bash
defaults delete com.hotslot.app com.hotslot.appSettings 2>/dev/null; true
```

## Flujo rápido (~15 min)

### Ola UX panel (validar antes de tag / DMG)

| Check | Qué mirar |
|-------|-----------|
| Apertura | Unfold más **rápido** (~0,55 s total); cuerpo pasa de tenue a opaco al expandir abajo. |
| Popover atajos | Clic en chip del slot → popover **compacto** (268 pt); filas Pegar / Guardar en una línea. |
| Historial | Pin **solo hover**; hover ~0,4 s → texto expande / imagen peek. |
| Slot imagen | Fill **sin desborde** del marco. |
| Título slot | Editar abajo → **Enter** o clic en la card → persiste. |
| Cruz vaciar | Hover → **×** a la izquierda; «Slot N» se corre. |
| Bibliotecas | Drag reorden + **tacho** al arrastrar; eliminar confirma. |
| Cabecera | Nombre biblioteca alineado con buscador. |

**Profundidad:** no hace falta probar *cada* ítem de menú en 7 y 9. Alcanza **1 acción representativa** por grupo (ver notas abajo).

Registro de la última pasada (Gianluca):

| Paso | Resultado |
|------|-----------|
| 1 Arranque / onboarding | Run Xcode: panel OK; splash pendiente desde Aplicaciones. Onboarding OK; polish menor después. |
| 2 Panel / ⌘⇧V | OK |
| 3 Bibliotecas | Pills OK; **+** sin modal → re-fix overlay (modal a nivel ventana). Re-probar tras pull. |
| 4 Guardar | **No requiere Accesibilidad.** Copiar texto → **Guardar portapapeles** → slot + sonido + píldora arriba (~1,5 s). |
| 5 Pegar | Bloqueado sin TCC / sin app en Aplicaciones. |
| 6 Historial pegar | Igual que 5 (clic en fila usa pegado). Drag historial → slot vacío **sí** se puede sin TCC. |
| 7 Slots menú | Smoke: clic derecho → **Renombrar** (o **Vaciar**). Resto en backlog si no hay tiempo. |
| 8 Ajustes | Tabs OK. Notch: toggle ON → **Probar aviso ahora** (General); no es la Dynamic Island de iPhone. |
| 9 Menú bar | Smoke: abrir **Ajustes** y **Ver todo** desde el menú. |

1. **Arranque** — Splash solo desde Aplicaciones; onboarding 3 pasos; panel al abrir la app.
2. **Panel** — ⌘⇧V: layout handoff, **Guardar portapapeles**.
3. **Bibliotecas** — Cambiar pill; **+** → modal “Nueva biblioteca” → Crear; slots distintos por biblioteca (ejemplo cargado).
4. **Guardar** — Copiar texto, **Guardar portapapeles** → primer slot vacío + **píldora** arriba (centro, bajo notch o menú). Con 5 llenos → modal elegir slot.
5. **Pegar** — Con TCC: ⌘⇧A/S/… en Notas; slot vacío → píldora “slot vacío”, sin pegar.
6. **Historial** — Con TCC: clic pega. **Sin TCC:** arrastrar fila a slot vacío.
7. **Slots** — Smoke: clic derecho → una opción (Renombrar / Vaciar / Mover a…).
8. **Ajustes** — General / Atajos / Permisos / Slots; **Probar aviso ahora** si el notch “no funciona”.
9. **Menú bar** — Smoke: **Ver todo**, **Ajustes** (no hace falta cada subítem).

## Accesibilidad (P0)

- [ ] ¿Aparece **Slots** en Ajustes del sistema → Privacidad → Accesibilidad? (mejor con `.app` en Aplicaciones o DMG)
- [ ] ¿Pegado con atajo funciona sin ⌘V manual?

En la app: **Ajustes → Permisos** muestra diagnóstico si el aviso TCC no salió. Arreglar el flujo TCC sigue en **BACKLOG P0**; no bloquea validar guardar ni bibliotecas.

## Eventos (moderador)

⌥ + clic menú → **Exportar eventos** → CSV en Application Support.

## Desvíos conocidos aceptables en este build

Ver **`docs/DESVIOS-DISENO-DANTE.md`**.

- TCC Accesibilidad sin resolver (P0).
- iOS / monetización activa: fuera de alcance.
