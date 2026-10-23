# Guide de revue pour Écluse

Rédige tes résumés et commentaires de revue **en français**.

Écluse est un sas de pseudonymisation entre un utilisateur et un LLM tiers.
Une erreur de détection n'est pas un bug cosmétique : c'est une donnée
personnelle qui part en clair. Relis en priorité ce qui peut **faire fuir**
une donnée, puis ce qui produit des **faux positifs**, puis le reste.

## Points à vérifier en priorité

1. **Fuite silencieuse.** Un format illisible, ambigu ou hors périmètre doit
   être refusé avec un motif explicite. Signale tout chemin qui renvoie
   « rien à masquer » sur un contenu non lu, ou qui avale une exception.
2. **Offsets.** Les positions des entités doivent pointer dans le texte
   d'origine, y compris après normalisation (espaces insécables,
   tabulations, compaction de chiffres). Signale tout décalage possible.
3. **Validation structurelle.** NIR, RPPS, IBAN, FINESS sont validés par
   leur clé de contrôle. Signale toute validation affaiblie ou contournée.
4. **Le LLM annote, il ne réécrit jamais le texte utilisateur.**
5. **Mesurer avant de corriger.** Une PR qui change la détection doit
   montrer le test qui révélait le défaut et une mesure avant/après.
   Signale son absence.
6. **Détecteurs purs** dans `ecluse_core` : pas de réseau, pas d'effet de
   bord, pas de dépendance native.

## Règles de confidentialité du dépôt (public)

- **Aucune donnée réelle** : signale tout identifiant, nom ou document qui
  ne semble pas synthétique dans le code, les tests ou les fixtures.
- **Aucun nom de prospect, d'établissement client ou de personne
  rencontrée** dans le code, les commentaires, les commits ou la PR.

## Ce qu'il ne faut pas commenter

- Le formatage : `dart format` est vérifié par la CI.
- Les préférences de style sans impact sur la sécurité ou la justesse.
