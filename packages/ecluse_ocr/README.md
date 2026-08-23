# ecluse_ocr

Interfaces Dart pures pour l'ingestion de documents **non-textuels** dans
Ecluse : PDF-image, scans, photos. Aucune dépendance native, aucune fuite
réseau depuis ce package.

## Ce qui change dans la ligne éditoriale

Historiquement, Ecluse refuse les formats OCR par principe : « un OCR
raté produit une fuite silencieuse ». Ce package ne remet pas ce principe
en cause — il le **raffine** :

> Refuser explicitement, jamais silencieusement.

Concrètement, une fois le texte extrait par une implémentation
[`OcrEngine`](lib/src/ocr_engine.dart), chaque token soupçonné d'être un
identifiant traverse la [`StructuralRevalidator`](lib/src/structural_revalidator.dart) :

- **Une seule variante ambiguë valide** un checksum structurel (Luhn NIR,
  RPPS, IBAN) → correction appliquée avec traçabilité (`origin: ocr`,
  `correction: [O→0]`).
- **Plusieurs variantes valident** → le texte n'est pas corrigé
  arbitrairement ; la zone est renvoyée à l'humain pour arbitrage.
- **Aucune variante ne valide** ET la zone ressemble structurellement à
  un identifiant → zone marquée en `RiskZone`, refus explicite,
  l'utilisateur voit exactement quoi.

Le silence est banni. Le pipeline continue avec ce qui a été validé, et
retourne une liste de zones à trancher — comme le fait déjà `ecluse_reid`
avec les classes d'équivalence.

## Ce que ce package n'est pas

- **Pas un OCR.** Aucun modèle vision ici. Voir `ecluse_ocr_docling`
  (pipeline Docling d'IBM en sidecar Python) ou un futur `ecluse_ocr_onnx`
  (Qwen 2.5-VL / Phi-3.5-vision en FFI ORT) pour l'extraction.
- **Pas un moteur de règles concurrent.** Il consomme les mêmes détecteurs
  que `ecluse_core` via l'interface `StructuralValidator`.

## Contrats

```dart
abstract interface class OcrEngine {
  Future<OcrPage> extract(Uint8List bytes, {required String mediaType});
  void close();
}

class StructuralRevalidator {
  RevalidationOutcome tryRevalidate(String noisy);
}

sealed class RevalidationOutcome {}
class Corrected extends RevalidationOutcome { ... }
class Ambiguous  extends RevalidationOutcome { ... }
class Unrecoverable extends RevalidationOutcome { ... }
```

## Statut

Scaffold. Le cœur (`AmbiguityResolver`, `StructuralRevalidator`,
`RiskZoneReporter`) est fonctionnel et testé. Pas de dépendance
d'exécution — testable sans OCR réel via les fakes des tests.

## Hors périmètre

- Manuscrit médical. Même les meilleurs VLM 2026 échouent sur la cursive
  de garde. Refus explicite maintenu.
- PDF texte natif. Devrait être adressé par `ecluse_ingest`, pas ici.
