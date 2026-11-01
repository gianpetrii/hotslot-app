# Prueba integrada — build rediseño macOS

Usar **al final** del tramo Etapa 4–5 (no hace falta validar cada commit). TCC Accesibilidad: anotar aparte si sigue sin listar la app.

## Antes

- **Validá con Run en Xcode** (Debug) usando esta checklist. El **DMG notarizado** va después.
- **Datos de ejemplo:** ⌥ + **clic derecho** en el icono de la barra → **Cargar ejemplo**.
- **Onboarding otra vez:** ⌥ + **clic derecho** → **Empezar de cero** (borra datos y abre los 3 pasos).
- **Splash / abrir desde Aplicaciones:** en Xcode, **Product → Show Build Folder in Finder** → `Products/Debug/Slots.app` → arrastrá a `/Applications` **o** abrí esa app una vez (no hace falta para el resto del flujo).

Reset manual (si hace falta):

```bash
defaults delete com.hotslot.app com.hotslot.appSettings 2>/dev/null; true
```

Luego volvé a Run en Xcode.

## Flujo rápido (~15 min)

1. **Arranque** — Al abrir desde Aplicaciones: splash naranja ~2 s; primera vez → onboarding 3 pasos; después → panel si abriste la app.
2. **Panel** — ⌘⇧V: panel grande, título de biblioteca, buscador, slots a la izquierda, historial a la derecha, pills abajo, **Guardar portapapeles**.
3. **Bibliotecas** — Cambiar pill; ⌥ menú → Biblioteca; slots distintos por biblioteca (con ejemplo cargado).
4. **Guardar** — Copiar texto, **Guardar portapapeles** → primer slot vacío + aviso notch. Con 5 llenos → elegir slot y reemplazar.
5. **Pegar** — ⌘⇧A/S/… con foco en Notas; slot vacío → aviso notch sin pegar.
6. **Historial** — Clic en fila pega; arrastrar fila a slot vacío.
7. **Slots** — Clic derecho: Renombrar, Reemplazar, Mover a…, Vaciar.
8. **Ajustes** — Sidebar General / Atajos / Permisos / Slots; Licencia visible; notch on/off.
9. **Menú bar** — Ver todo, Biblioteca, Ajustes, Licencia.

## Accesibilidad (P0)

- [ ] ¿Aparece Slots en Ajustes → Privacidad → Accesibilidad?
- [ ] ¿Pegado con atajo funciona sin ⌘V manual?

Si falla: documentar build, bundle ID y si instalaste desde DerivedData vs `/Applications`.

## Eventos (moderador)

⌥ + clic menú → **Exportar eventos** → CSV en Application Support.

## Desvíos conocidos aceptables en este build

Ver lista para Dante: **`docs/DESVIOS-DISENO-DANTE.md`** (actualizar estados tras su feedback).

- TCC Accesibilidad sin resolver (P0).
- iOS / monetización activa: fuera de alcance.