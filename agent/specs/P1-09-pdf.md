# P1-09 — Ingestion PDF texte et garde-fou PDF-image

Type : `spec`. Aucun code de production, aucune dépendance ajoutée.

## 0. Niveau de vérification

Les fiches des paquets ci-dessous ont été lues sur pub.dev (via l'outil de
l'agent, qui résume la page : les chiffres de popularité et les dates sont
donc **relatifs au moment de la lecture, le 25 oct. 2026**). Rien n'a été
installé ni exécuté : **aucune extraction n'a été testée sur un PDF**. Tout
seuil du §3 est une **proposition à calibrer**, pas une mesure.

## 1. Contraintes du projet

- `ecluse_ingest` est aujourd'hui en Dart pur (`archive` seul) ; `CLAUDE.md`
  interdit aussi toute dépendance native dans `ecluse_core`. Licence du
  dépôt : Apache 2.0.
- Offsets : le texte extrait est ce que `Ecluse.redact` reçoit tel quel ;
  les offsets valent donc **par rapport au texte extrait** (comme pour
  `.docx`), pas par rapport au PDF. Aucune transformation entre extraction
  et détection.
- Règle n°4 : tout PDF illisible, ambigu ou partiellement lu est **refusé
  avec un motif**, jamais « rien à masquer ».
- `magic_bytes.dart` reconnaît déjà `%PDF` : un PDF déguisé en `.txt` est
  déjà refusé. Aujourd'hui un `.pdf` est hors périmètre (`IngestFormat` =
  `txt, md, docx, odt`).

## 2. Comparaison des bibliothèques

| Paquet | Licence | Nature | Maintenance (à la lecture) | Verdict |
|---|---|---|---|---|
| [`pdf_graphics`](https://pub.dev/packages/pdf_graphics) 10.0.0 | Apache-2.0 | Dart pur, sans Flutter ni `dart:ui` ; extraction via `PdfPageText.extract` (géométrie des caractères, ordre de lecture, rotation) | Éditeur vérifié ; publiée « il y a 6 jours » ; numéro de version majeur élevé (historique de versions rapide : à regarder) | **Seul candidat compatible** avec les contraintes |
| [`dart_mupdf_donut`](https://pub.dev/packages/dart_mupdf_donut) 1.0.0 | MIT | Dart pur, `getText()` / blocs / mots avec rectangles | Éditeur non vérifié, 1 like, 59 téléchargements, publiée il y a ~8 mois | Trop peu éprouvée pour un chemin de sécurité |
| [`pdfrx`](https://pub.dev/packages/pdfrx) 2.10.1 | MIT | PDFium natif, dépend de Flutter | Très active | Écartée : natif + Flutter (inadaptée à un paquet Dart pur) ; offsets de texte non documentés sur la fiche |
| [`syncfusion_flutter_pdf`](https://pub.dev/packages/syncfusion_flutter_pdf) 35.1.41 | Commerciale / Community (« unknown » sur pub.dev) | Dépend de Flutter, `PdfTextExtractor` | Très active | Écartée : licence incompatible avec Apache 2.0 sans conditions, Flutter |
| Enveloppes de `xpdf`/`pdftotext` (ex. `pdf_text_extraction`) | non vérifiée (xpdf est sous GPL [non vérifié]) | Natif Linux/Windows seulement | non vérifiée | Écartée a priori |

Le paquet `pdf` (génération de PDF) n'est pas un extracteur et n'est pas
comparé.

**Recommandation : `pdf_graphics`**, derrière une interface interne mince
(`PdfTextSource`) pour pouvoir le remplacer. Avant toute adoption :

1. relire sa licence **et celle de toutes ses dépendances transitives**
   (`pdf_cos`, `pdf_document`, `bidi`, `image`…) ;
2. l'essayer sur des PDF **synthétiques que nous générons** (ligatures,
   césures, colonnes, texte vertical, polices sans `ToUnicode`) pour
   mesurer la qualité du texte rendu ;
3. évaluer sa résistance aux PDF malformés (voir §4).

## 3. Garde-fou PDF-image

Principe : un PDF n'est accepté que si l'on peut affirmer que **tout son
contenu informatif est du texte lu**. Sinon refus du document entier.

### Cas à traiter

| Cas | Décision |
|---|---|
| Aucun texte sur aucune page (scan pur) | **Refus** : « PDF sans couche texte (image/scan) : hors périmètre » |
| Couche texte quasi vide (OCR raté, quelques caractères) | **Refus** (seuil ci-dessous) |
| PDF **mixte** : certaines pages texte, d'autres images | **Refus du document entier**, avec la liste des pages sans texte. Ne jamais masquer « ce qui est lisible » en laissant des pages non lues |
| Page volontairement blanche (aucun texte, aucune image) | Acceptée si l'on sait distinguer « page vide » de « page image » ; sinon refus (conservateur) |
| Texte présent mais **illisible** (police sans `ToUnicode`, glyphes en zone privée, caractères de remplacement) | **Refus** : texte non-vide ≠ texte lu |
| PDF chiffré / protégé par mot de passe | **Refus** : « PDF chiffré » |
| PDF malformé, xref cassé, trop gros, trop de pages | **Refus** avec motif ; plafonds de taille/pages/temps |
| Texte natif + image de signature/tampon/en-tête | Accepté **avec avertissement** (`warnings`) : les éléments non textuels ne sont pas traités (le faux sentiment de sécurité décrit dans `ROADMAP.md`, « périmètre d'entrée ») |

### Seuils proposés (à calibrer sur PDF synthétiques)

1. **Page « avec texte »** : au moins **20 caractères alphanumériques**
   extraits. Valeur de départ arbitraire, à ajuster.
2. **Document accepté** seulement si **100 %** des pages non blanches sont
   « avec texte ». Tolérance zéro : un ratio de pages sans texte (par exemple
   « 90 % suffisent ») produirait précisément le faux sentiment de sécurité
   à éviter.
3. **Qualité du texte** : refuser si, sur le texte extrait d'une page,
   - la part de caractères `U+FFFD`, de zone privée Unicode (`U+E000–F8FF`)
     ou de contrôle dépasse **5 %**, ou
   - la part de lettres/chiffres est inférieure à **50 %** des caractères non
     blancs.
4. Détecter « page image » = présence d'un objet image couvrant une part
   notable de la page : **dépend de ce que `pdf_graphics` expose** [non
   vérifié]. À défaut, l'option conservatrice est de refuser toute page sans
   texte, blanche ou non.

### Messages de refus (français, affichés tels quels)

- « PDF sans texte exploitable (scan ou image) : Écluse ne traite pas les
  images. »
- « PDF partiellement numérisé : les pages N, M… ne contiennent pas de texte.
  Le document est refusé en entier. »
- « Texte du PDF illisible (encodage de polices) : document refusé. »
- « PDF chiffré : document refusé. »

## 4. Sécurité et robustesse

- Plafonds : taille du fichier (50 Mo comme `maxSafeZipEntryBytes`),
  nombre de pages, durée d'extraction, mémoire. Valeurs à décider.
- Un PDF est un format actif et complexe : l'extraction doit tourner **sans
  exécuter de JavaScript ni suivre de liens**, et toute exception interne doit
  devenir `IngestRefused`, jamais un texte vide.
- Fuzzing minimal recommandé sur PDF tronqués/corrompus (générés).
- **Hors texte de page** : métadonnées (`/Info` : auteur, titre), annotations,
  champs de formulaire, signets, pièces jointes peuvent contenir des
  identifiants. Décision à prendre : les extraire et les inclure dans le
  texte, ou refuser/avertir si présents. Par défaut proposé : **avertissement
  explicite** si présents et non extraits.
- Ordre de lecture (colonnes, tableaux) et césures : un identifiant coupé
  par un retour à la ligne ou par une césure peut échapper à la détection.
  Limite à documenter dans `LIMITES.md`.

## 5. Interface proposée (pas de code)

`ingestFile` accepte `.pdf` et renvoie `IngestedText(format: pdf, …)` ou
`IngestRefused(motif)`. Ajout de `IngestFormat.pdf`. Les motifs ci-dessus sont
des constantes testables.

## 6. Plan de tests (futur ticket `code`)

PDF **synthétiques générés par script** : texte simple ; deux pages dont une
image ; scan pur ; chiffré ; texte sans `ToUnicode` ; tronqué ; très long ;
avec métadonnées. Pour chacun : résultat attendu (accepté/refusé + motif),
et pour les acceptés, offsets exacts d'un NIR/RPPS/IBAN fabriqués.

## 7. Risques

1. **Maturité de `pdf_graphics`** : paquet récent, mainteneur unique, dépôt
   non audité par nous. Mitigation : interface interne, tests synthétiques,
   possibilité de repli.
2. **Qualité d'extraction** : texte déformé = détection manquée silencieuse.
   C'est le risque principal et il n'est pas mesuré ici.
3. **Seuils arbitraires** : à calibrer avant fusion.
4. **Licences transitives** non auditées.
5. **Dépendance ajoutée** : interdite sans accord ; ce document ne l'ajoute pas.

## 8. Décisions demandées au mainteneur

1. Autoriser l'ajout de `pdf_graphics` à `ecluse_ingest` (après audit de
   licence) ou refuser tout PDF pour la v1.
2. Valider la politique « refus du document entier » pour les PDF mixtes.
3. Choisir le traitement des métadonnées/annotations (§4).
4. Fixer les plafonds (taille, pages, durée).
