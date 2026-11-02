"""
Sidecar Docling pour Ecluse.

Expose un endpoint POST /extract qui reçoit un fichier binaire et
retourne la structure OCR au format attendu par `DoclingParser`
(voir packages/ecluse_ocr_docling/lib/src/docling_parser.dart).

Ne bind que sur 127.0.0.1 — voir démarrage recommandé dans le README.
"""

from __future__ import annotations

import io
import tempfile
from pathlib import Path
from typing import Any

from fastapi import FastAPI, File, HTTPException, UploadFile

# NOTE: import différé de docling — le sidecar peut démarrer sans docling
# installé pour permettre un test à vide.
try:
    from docling.document_converter import DocumentConverter  # type: ignore
    _DOCLING_AVAILABLE = True
except Exception:  # pragma: no cover
    DocumentConverter = None  # type: ignore
    _DOCLING_AVAILABLE = False

app = FastAPI(title="ecluse-docling-sidecar", version="0.1.0")


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "docling_available": _DOCLING_AVAILABLE,
    }


@app.post("/extract")
async def extract(file: UploadFile = File(...)) -> dict[str, Any]:
    if not _DOCLING_AVAILABLE:
        raise HTTPException(
            status_code=503,
            detail="docling non installé dans le venv du sidecar",
        )

    data = await file.read()
    with tempfile.NamedTemporaryFile(
        suffix=_suffix_for(file.content_type or ""),
        delete=False,
    ) as tmp:
        tmp.write(data)
        tmp_path = Path(tmp.name)

    try:
        converter = DocumentConverter()
        result = converter.convert(str(tmp_path))
        return _serialize(result)
    finally:
        try:
            tmp_path.unlink()
        except OSError:
            pass


def _suffix_for(mime: str) -> str:
    return {
        "application/pdf": ".pdf",
        "image/png": ".png",
        "image/jpeg": ".jpg",
        "image/tiff": ".tif",
    }.get(mime, "")


def _serialize(result: Any) -> dict[str, Any]:
    """
    Convertit la sortie Docling en JSON stable pour Ecluse.

    L'API Docling évolue ; cette fonction est le seul point à mettre à
    jour quand une nouvelle version change le shape des objets. Le format
    de sortie doit rester conforme à ce qu'attend DoclingParser côté
    Dart.
    """
    pages: list[dict[str, Any]] = []

    # NOTE: implémentation à finir en fonction de la version Docling
    # retenue. Pour l'instant : squelette minimal — un test manuel sur
    # un PDF réel finalisera le mapping.
    doc = getattr(result, "document", result)
    doc_pages = getattr(doc, "pages", []) or []

    for i, page in enumerate(doc_pages):
        regions: list[dict[str, Any]] = []
        for reg_id, item in enumerate(getattr(page, "elements", []) or []):
            box = getattr(item, "bbox", None)
            if box is None:
                continue
            tokens = []
            for tok_id, tok in enumerate(getattr(item, "tokens", []) or []):
                tok_box = getattr(tok, "bbox", box)
                tokens.append({
                    "text": getattr(tok, "text", ""),
                    "conf": float(getattr(tok, "confidence", 1.0)),
                    "box": _box(tok_box),
                })
            regions.append({
                "id": f"p{i}_r{reg_id}",
                "kind": _kind_of(item),
                "parent_id": None,
                "box": _box(box),
                "tokens": tokens,
            })
        pages.append({
            "index": i,
            "width": int(getattr(page, "width", 0) or 0),
            "height": int(getattr(page, "height", 0) or 0),
            "regions": regions,
            "warnings": [],
        })

    return {"pages": pages}


def _box(bbox: Any) -> dict[str, int]:
    return {
        "x": int(getattr(bbox, "l", getattr(bbox, "x", 0)) or 0),
        "y": int(getattr(bbox, "t", getattr(bbox, "y", 0)) or 0),
        "w": int(getattr(bbox, "w", 0) or 0),
        "h": int(getattr(bbox, "h", 0) or 0),
    }


def _kind_of(item: Any) -> str:
    label = str(getattr(item, "label", "") or "").lower()
    if "title" in label or "heading" in label:
        return "heading"
    if "cell" in label:
        return "table_cell"
    if "row" in label:
        return "table_row"
    if "table" in label:
        return "table"
    if "line" in label:
        return "line"
    if "paragraph" in label or "text" in label:
        return "paragraph"
    return "other"
