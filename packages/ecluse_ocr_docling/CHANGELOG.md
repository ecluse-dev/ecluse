## 0.1.0 - 2026-08-11

- Scaffold initial.
- `DoclingClient` : implémentation `OcrEngine` via HTTP local.
- `DoclingParser` : conversion de la réponse Docling en `OcrPage`.
- `DoclingConfig` : URL du sidecar, timeout, `verifySidecarBoundToLoopback`.
- Sidecar Python de référence dans `sidecar/` (FastAPI + Docling).
- Test d'intégration hors process : client fait ses appels à un
  serveur HTTP factice monté dans le test (`shelf` non requis — dart:io).
