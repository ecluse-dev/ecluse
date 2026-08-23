# ecluse_ocr_docling

Implémentation `OcrEngine` d'Ecluse via un **sidecar Python Docling**
(IBM). Docling est aujourd'hui l'outil le plus fiable pour convertir un
PDF ou une image en markdown structuré (paragraphes, tableaux, cellules)
avec des bounding boxes exploitables.

## Pourquoi un sidecar, pas de la FFI

Docling est une lib Python qui repose sur PyTorch, ONNX, plusieurs
modèles vision. Un binding FFI directement en Dart est disproportionné
face à un serveur HTTP local qui répond en ~200 ms. Le sidecar tourne
sur `127.0.0.1` uniquement, pas de fuite réseau.

Le client Dart peut être configuré pour refuser de démarrer si l'URL
n'est pas une loopback (`verifySidecarBoundToLoopback: true`, valeur
par défaut).

## Bootstrap du sidecar

```bash
cd packages/ecluse_ocr_docling/sidecar
python -m venv venv
source venv/bin/activate  # Windows : venv\Scripts\activate
pip install -r requirements.txt
uvicorn app:app --host 127.0.0.1 --port 8790
```

Le premier lancement télécharge les modèles Docling (~2 Go, cache local
`~/.cache/docling/`).

## Utilisation Dart

```dart
final client = DoclingClient(
  config: DoclingConfig(
    baseUrl: Uri.parse('http://127.0.0.1:8790'),
    timeout: Duration(seconds: 30),
  ),
);
final pages = await client.extract(bytes, mediaType: 'application/pdf');
client.close();
```

## Formats supportés côté sidecar

- `application/pdf` (image ou texte, Docling détecte)
- `image/png`, `image/jpeg`, `image/tiff`

## Formats non supportés

- Manuscrit — Docling refuse, pas d'HTR fiable en 2026.
- Formats non-image / non-PDF — remonter en `OcrUnsupportedFormatException`.

## Statut

Scaffold. Le client Dart et le sidecar FastAPI sont écrits. Il reste à :

1. Fixer la version Docling (recommandé : ≥ 3.0 pour le support tableau
   robuste).
2. Éprouver le mapping bounding-boxes Docling → `BoundingBox` d'Ecluse
   sur des documents réels (voir critère GO/STOP dans `INTEGRATION.md`).
