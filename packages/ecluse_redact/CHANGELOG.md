# Changelog — ecluse_redact

## 0.2.0

**Rupture d'API (P2-193, décisions du 15 novembre dans `DECISIONS.md`).**

- `RedactResult.mapping` n'est plus un `Map<String, String>` mais une
  `TableDeCorrespondance` : `toString()` ne donne que le nombre de jetons
  (jamais un jeton ni une valeur), pas de sérialisation implicite
  (`jsonEncode` refuse), pas d'`==`, `vider()` efface le contenu. Opérations :
  `length`, `isEmpty`, `isNotEmpty`, `jetons`, `[]`, `contient`, `entrees`
  (couples `(jeton, valeur)`), `vider()`.
- `Ecluse.restore` et `Ecluse.restoreAvecRapport` exigent une
  `TableDeCorrespondance`. Une table construite à la main passe par
  `TableDeCorrespondance.depuis(Map)` (recopie la carte).
- Migration : `result.mapping.keys` → `.jetons` ; `.length` inchangé ;
  `.values` et `.entries` → `.entrees` (`e.$1` jeton, `e.$2` valeur) ;
  comparer deux tables → comparer leurs `entrees`.
- La table n'est pas chiffrée : rien n'est conservé hors de la mémoire du
  processus (`LIMITES.md`).

## 0.1.0

Première version interne.
