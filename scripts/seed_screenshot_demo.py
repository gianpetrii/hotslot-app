#!/usr/bin/env python3
"""Carga historial y slots de demo para capturas de App Store."""

import json
import shutil
import uuid
from datetime import datetime, timedelta
from pathlib import Path

CONTAINER = Path.home() / "Library/Containers/com.hotslot.app/Data/Library/Application Support/HotSlot"
LEGACY = Path.home() / "Library/Application Support/HotSlot"
BUNDLED_IMAGE = Path(__file__).resolve().parents[1] / "HotSlot/Resources/onboarding-demo.png"
DEMO_IMAGE = "screenshot-demo-ui.png"


def apple_ref_date(when: datetime) -> float:
    ref = datetime(2001, 1, 1)
    return (when - ref).total_seconds()


def text_item(body: str, app: str, bundle: str, minutes_ago: int, pinned: bool = False) -> dict:
    return {
        "id": str(uuid.uuid4()).upper(),
        "content": {"text": {"_0": body}},
        "createdAt": apple_ref_date(datetime.now() - timedelta(minutes=minutes_ago)),
        "sourceAppName": app,
        "sourceAppBundleID": bundle,
        "isPinned": pinned,
    }


def image_item(app: str, bundle: str, minutes_ago: int) -> dict:
    return {
        "id": str(uuid.uuid4()).upper(),
        "content": {"image": {"fileName": DEMO_IMAGE}},
        "createdAt": apple_ref_date(datetime.now() - timedelta(minutes=minutes_ago)),
        "sourceAppName": app,
        "sourceAppBundleID": bundle,
        "isPinned": False,
    }


def slots() -> list:
    return [
        {
            "index": 1,
            "label": "Slot 1",
            "content": {
                "text": {
                    "_0": "Link de la reunión\nhttps://meet.ejemplo.com/sala-producto-042"
                }
            },
        },
        {
            "index": 2,
            "label": "Slot 2",
            "content": {
                "text": {
                    "_0": "Hola {nombre},\n\nGracias por escribirnos. Te respondemos en 24 h hábiles.\n\nSaludos,\nEquipo Soporte"
                }
            },
        },
        {"index": 3, "label": "Slot 3", "content": None},
        {
            "index": 4,
            "label": "Slot 4",
            "content": {
                "text": {
                    "_0": "SELECT id, email, created_at\nFROM users\nWHERE active = true\nORDER BY created_at DESC\nLIMIT 50;"
                }
            },
        },
        {
            "index": 5,
            "label": "Slot 5",
            "content": {"text": {"_0": "git checkout -b feature/hotslot-release"}},
        },
    ]


def history() -> list:
    return [
        text_item(
            "Notas — sync de producto\n\n"
            "• Definir copy de App Store\n"
            "• Capturas del panel con historial y slots\n"
            "• Probar pegado en Safari, Notas y Chrome\n"
            "• Revisar permiso de Accesibilidad\n\n"
            "Link de la sala: https://meet.ejemplo.com/sala-producto-042",
            "Safari",
            "com.apple.Safari",
            2,
        ),
        image_item("Captura de pantalla", "com.apple.GrabadorPantalla", 6),
        text_item(
            "Hola {nombre},\n\nGracias por tu mensaje. Te escribimos en cuanto tengamos novedades.\n\nSaludos,\nMaría · Soporte",
            "Mail",
            "com.apple.mail",
            11,
            pinned=True,
        ),
        text_item(
            "https://docs.api.ejemplo.com/v2/auth/token",
            "Google Chrome",
            "com.google.Chrome",
            18,
        ),
        text_item(
            'const payload = { userId, scope: ["read", "write"] };\nawait fetch("/api/session", { method: "POST", body: JSON.stringify(payload) });',
            "Cursor",
            "com.todesktop.230313mzl4w4u92",
            25,
        ),
    ]


def write_bundle(root: Path) -> None:
    root.mkdir(parents=True, exist_ok=True)
    images = root / "Images"
    images.mkdir(exist_ok=True)
    if BUNDLED_IMAGE.exists():
        shutil.copy2(BUNDLED_IMAGE, images / DEMO_IMAGE)
    (root / "history.json").write_text(json.dumps(history(), indent=2), encoding="utf-8")
    (root / "slots.json").write_text(json.dumps(slots(), indent=2), encoding="utf-8")
    print(f"Demo data written to {root}")


def main() -> None:
    write_bundle(CONTAINER)
    if LEGACY.exists():
        write_bundle(LEGACY)


if __name__ == "__main__":
    main()
