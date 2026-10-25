# Journal des décisions

Trace écrite des choix structurants, pour ne pas re-débattre avec
soi-même et éclairer les contributeurs.

## 2026-06 — Dart d'abord, Rust plus tard
Vélocité solo > pureté d'architecture. Le cœur pourra migrer en Rust
derrière la même API quand le revenu justifiera la complexité.

## 2026-06 — Licence Apache 2.0
Permissive, patent grant rassurant pour les juristes d'entreprise,
compatible open-core. MIT écarté (pas de patent grant), AGPL écartée
(freine l'adoption B2B).

## 2026-06 — Détection stricte (clé validée ou rien)
Les détecteurs ne retournent que des entités structurellement validées.
Faux positifs ≈ 0 est l'argument du futur benchmark vs Presidio.
La confiance graduée existe dans l'API pour les détecteurs futurs
(NER local) qui ne pourront pas valider structurellement.

## 2026-06 — Zéro communication avant preuve
Pas d'annonce publique tant que le benchmark vs Presidio n'est pas
publiable. Premier post = chiffres en main.

## 2026-10 — Specs de phase 1 : décisions prises sur recommandation de l'agent
Décisions rédigées par un agent à la demande du mainteneur (« selon tes
recommandations »), à relire à la fusion. Chaque point renvoie à sa spec
dans `agent/specs/`. Ce qui ne peut pas être tranché sans source externe
est marqué **ouvert**.

### ADELI (`P1-06-adeli.md`)
- Type `EntityType.adeli` ajouté, émis **uniquement avec le mot « ADELI »**
  à proximité ; sans mot-clé, `FinessDetector` continue de masquer les
  nombres Luhn-valides.
- Priorité à `adeli` sur `finess` pour un même span quand le mot-clé est
  présent.
- **Ouvert** : structure, clé de Luhn et règle de la lettre corse à
  confirmer sur la fiche officielle de l'ASIP avant tout code.
- **En tension avec « Détection stricte »** : masquer à confiance 0,6 un
  numéro à clé invalide mais étiqueté « ADELI » déroge à « clé validée ou
  rien ». Retenu à titre d'exception documentée (un champ explicitement
  étiqueté qui fuit est pire qu'un sur-masquage), **à confirmer
  explicitement**.

### Secrets (`P1-07-secrets.md`)
- Périmètre étendu aux secrets (clés d'API, jetons, clés privées PEM,
  chaînes de connexion avec mot de passe).
- Un seul `EntityType.secret`, détecteur de tier `pattern`.
- Comportement par défaut : masquer + avertissement ; mode strict optionnel
  qui refuse. Restauration désactivée par défaut pour ce type.
- Chaîne de connexion : masquer `utilisateur:motdepasse`.
- Pas de détection par entropie en v1.
- **Ouvert** : liste finale des fournisseurs ; licence de la source de
  motifs (gitleaks) à confirmer avant toute réutilisation (motifs à
  réécrire par nous dans tous les cas).
- **En tension avec « Détection stricte »** : aucun secret n'a de clé de
  contrôle vérifiable ici ; la confiance est celle d'un motif, comme pour
  le téléphone et l'email.

### Audit (`P1-08-audit.md`)
- **Pas d'empreinte du texte** en v0 (HMAC éventuel en v1, jamais de hash
  simple).
- Horodatage **à la minute**, sans identifiant utilisateur.
- Nouveau paquet `ecluse_audit` ; la bibliothèque ne stocke rien.
- Dépendance de hachage (`package:crypto`) **autorisée sous réserve** de
  confirmer sa licence ; elle n'est ajoutée que par la tâche de code
  correspondante.
- Ancrage externe et signature de la tête de chaîne : hors v0, à ouvrir en
  v1.
- **Ouvert** : validation par un DPO que le journal n'est pas une donnée
  personnelle ; ce n'est pas un avis juridique.

### PDF (`P1-09-pdf.md`)
- `pdf_graphics` retenu comme candidat, derrière une interface interne
  remplaçable, **sous réserve** d'un audit de ses licences transitives et
  d'un essai sur PDF synthétiques. Aucune dépendance ajoutée par cette
  décision.
- PDF mixte (pages texte et pages image) : **refus du document entier**.
- Métadonnées, annotations et formulaires : avertissement explicite s'ils
  existent et ne sont pas extraits.
- Seuils de départ : 20 caractères alphanumériques par page, 100 % des
  pages non blanches, 5 % de caractères parasites, plafond de taille de
  50 Mo ; **à calibrer** sur PDF synthétiques avant fusion. Plafonds de
  pages et de durée : **ouverts**.

### FINESS (`P1-03-finess.md`)
- Piste « contexte obligatoire » écartée (rappel 66,7 %).
- Avant toute correction : enrichir le corpus (SIREN sans mot-clé, phrases
  mêlant FINESS et SIREN), puis mesurer.
