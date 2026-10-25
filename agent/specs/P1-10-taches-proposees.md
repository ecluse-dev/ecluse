# Tâches `code` proposées après les specs de phase 1

`agent/QUEUE.md` est une zone interdite à l'agent : ces lignes sont
**à copier par le mainteneur** dans la file, dans l'ordre qu'il choisit.
Elles découlent des décisions de `DECISIONS.md` (2026-10). Les dépendances
indiquées sont celles de la fiche, pas un ordre de priorité.

| Id proposé | Type | Tâche | Dépend de | Bloquants à lever d'abord |
|---|---|---|---|---|
| P1-13 | code | Corpus : SIREN sans mot-clé, phrases FINESS + SIREN, ADELI avec/sans mot-clé (nouvelle version du générateur, mesures avant/après) | — | — |
| P1-14 | code | Détecteur ADELI contextuel + `EntityType.adeli` + priorité sur `finess` | P1-13 | Structure et clé confirmées sur la fiche ASIP ; règle de la lettre corse |
| P1-15 | code | Détecteur de secrets (`EntityType.secret`, motifs réécrits, avertissement, restauration désactivée) | P1-13 | Liste des fournisseurs ; licence de la source de motifs |
| P1-16 | code | `ecluse_audit` v0 (entrée, chaîne, vérificateur, sink en mémoire) | — | Licence de `package:crypto` ; accord DPO |
| P1-17 | code | Ingestion PDF : interface `PdfTextSource`, `pdf_graphics`, garde-fou et refus | — | Audit des licences transitives ; essai sur PDF synthétiques ; plafonds pages/durée |
| P1-18 | code | Générateur de PDF synthétiques pour calibrer les seuils (texte, scan, mixte, chiffré, illisible) | — | — |

Ordre conseillé : P1-13 d'abord (mesurer avant de corriger), P1-18 avant
P1-17.

Aucune de ces tâches n'est prise par l'agent tant qu'elle n'est pas dans
`agent/QUEUE.md`.
