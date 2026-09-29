# Capturas Mac App Store — HotSlot

Subí los PNG de **`1280x800/`** en App Store Connect.

| Archivo | Contenido |
|---------|-----------|
| `01-panel-principal.png` | Panel: slots + historial |
| `02-slot-peek.png` | Peek al hover en slot 1 |
| `03-historial-imagen.png` | Imagen expandida en historial |

- **`source/`** — capturas originales (sin procesar).
- **`2560x1600/`** — misma composición al doble (opcional).

Regenerar tras cambiar `source/`:

```bash
python3 scripts/process_app_store_screenshots.py
```

El script recorta el fondo oscuro y escala a 1280×800 sin marco exterior.
