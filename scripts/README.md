# Scripts de desarrollo

| Script | Uso |
|--------|-----|
| `seed_screenshot_demo.py` | Carga historial/slots de demo para capturas de App Store |
| `process_app_store_screenshots.py` | Recorta y exporta PNG en `docs/app-store-screenshots/` |

```bash
python3 scripts/seed_screenshot_demo.py
python3 scripts/process_app_store_screenshots.py
```

Las capturas fuente van en `docs/app-store-screenshots/source/`. Los PNG listos para subir están en `1280x800/`.
