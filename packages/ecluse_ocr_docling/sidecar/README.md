# Sidecar Docling

Service HTTP local qui expose Docling au client Dart d'Ecluse.

## Prérequis

- Python 3.11+
- ~2 Go de RAM libres pour Docling au repos, plus ~2 Go supplémentaires
  au premier lancement (téléchargement modèles).

## Installation

```bash
cd sidecar
python -m venv venv
source venv/bin/activate   # Windows PowerShell : venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## Démarrage

```bash
uvicorn app:app --host 127.0.0.1 --port 8790
```

**Ne jamais** binder sur `0.0.0.0`. Le client Dart refuse par défaut
toute URL non-loopback (`DoclingConfig.verifySidecarBoundToLoopback`).

## Endpoints

- `GET /health` → `{"status":"ok","docling_available":true}` si le venv
  contient bien Docling.
- `POST /extract` — multipart, champ `file` = octets du document. Réponse
  JSON au format attendu par `DoclingParser` (Dart).

## Notes

- Le mapping bboxes Docling → format Ecluse est à **valider sur documents
  réels** avant tout déploiement. La fonction `_serialize` dans `app.py`
  est écrite défensivement mais s'appuie sur des attributs qui peuvent
  changer entre versions Docling.
- Le sidecar ne persiste rien : le fichier temp est supprimé après
  extraction.
