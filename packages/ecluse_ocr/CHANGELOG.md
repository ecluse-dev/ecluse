## 0.1.0 - 2026-08-11

- Scaffold initial.
- Interfaces `OcrEngine`, types `OcrPage`, `OcrRegion`, `OcrToken`, `BoundingBox`.
- `AmbiguityResolver` : générateur de variantes plausibles (O↔0, I↔1,
  S↔5, B↔8, Z↔2, G↔6, T↔7, l↔1, rn↔m, cl↔d).
- `StructuralRevalidator` : rejoue les checksums NIR / RPPS / IBAN /
  FINESS sur toutes les variantes ambiguës jusqu'à en trouver zéro, une,
  ou plusieurs qui valident.
- `RiskZoneReporter` : signale les zones à confiance basse qui ressemblent
  structurellement à des identifiants (pas de fuite silencieuse).
- Ligne éditoriale gravée dans le code : correction si UNE variante valide,
  main à l'humain si plusieurs, refus explicite si aucune.
