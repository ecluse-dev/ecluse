# État des mesures — tableau de bord (P2-130)

Toutes les mesures du dépôt rejouées d'un coup sur `main` au commit
**`d85fb84`** (6 novembre 2026), graine 42 partout, puis rejouées au commit
**`a263a83`** (7 novembre, après P2-136 à P2-141) ; les lignes modifiées le
disent. Depuis, ce fichier est mis à jour section par section à chaque
tâche fusionnée qui change une mesure (voir les dates et les identifiants
de tâche cités dans chaque section — les plus récents au 13 novembre 2026) ;
`d85fb84` et `a263a83` ne décrivent donc plus l'état entier du fichier, seul
le rejeu d'origine (P2-130). Commande :

```bash
bash bench/etat.sh > etat.log 2>&1   # depuis la racine, Dart et Python requis
```

Dédoublonnage (P2-257, 22 novembre 2026, base `main` au commit `91d009c`) :
18 titres de section figuraient deux fois (17 blocs identiques, 1 divergent,
« SIREN nommé ») ; chacun ne figure plus qu'une fois, à sa première place. Aucun
chiffre n'a changé ; le script `bench/dedoublonne_etat.py` le vérifie.

Fiabilité du script (P2-168). `bench/etat.sh` ne tait plus une ligne attendue
et ne masque plus un échec : une commande qui échoue, un fichier de sortie
absent ou vide, un filtre qui ne trouve rien s'impriment « ÉCHEC : … » ou
« section vide : … » et le script sort avec un code non nul. Il vérifie sa
propre sortie contre `bench/etat_attendu.py` (une liste de lignes attendues par
section) et supprime d'abord tous les fichiers générés d'un rejeu précédent :
un résultat manquant ne peut plus être remplacé par un ancien. Ajouter une
ligne au tableau de bord, c'est ajouter son motif à `etat_attendu.py`.

Corpus **synthétiques** uniquement ; aucun chiffre ne vaut fréquence réelle.
Presidio n'est pas rejoué ici (environnement à part, `bench/README.md`,
« Reproduire ») ; ses chiffres de référence datent de la relecture P1-12.

## Identifiants structurels (corpus v3, 1 000 documents, 943 entités dont 72 `siren`)

| Corpus | Précision | Rappel | F1 | FP | Source |
|---|---:|---:|---:|---:|---|
| v3 d'origine, **tous types** (moteur seul) | **100 %** | 100 % | **100 %** | **0** | 23/11 (P2-261) : les 42 SIREN et 30 SIRET sont annotés `siren` (943 entités ; texte inchangé, empreinte SHA-256 identique) ; avant : 92,4 % / 100 % / 96,0 % / 72 ; 23/11 (P2-259) : les 30 SIRET pièges sont masqués, non annotés (avant : 95,4 % / 97,6 % / 42) ; 23/11 (P2-258) : les 45 NIR à clé fausse sont annotés (871 entités ; avant : 95,2 % / 97,5 % sur 826) ; 22/11 : les 48 IBAN à clé fausse sont annotés (826 entités) ; avant : 89,6 % / 94,5 % / 90 sur 778 ; avant P2-252 : 94,9 % / 97,4 % / 42 |
| v3 d'origine, **types communs** (NIR, RPPS, IBAN, FINESS ; `siren` retiré de l'or et des prédictions) | 100 % | 100 % | 100 % | 0 | P2-261 ; 871 entités ; identique à l'ancien total (la ligne `siren` : 72 TP, 0 FP, 0 FN, à part) |
| v3 sans ponctuation, minuscules | 100 % | 100 % | 100 % | 0 | P2-261 (avant : 92,4 % / 100 % / 96,0 % / 72 ; = P2-98 pour le reste de l'historique) |
| v3 nombres en lettres | 0 % | **0 %** | 0 % | 0 | = P2-98 |

**P2-263 (23 novembre 2026, soir)** : un NIR à clé fausse sans libellé est maintenant
lu aussi coupé par une fin de ligne, en chiffres pleine chasse ou en cinq groupes de
trois (`Ecluse.redact`, confiance 0,3, « à vérifier »). Seule ligne du tableau de bord
qui change : « structurel largeur 60, `Ecluse.redact` », NIR **313/314 → 314/314**
(total 942/943 → 943/943) ; la lecture du moteur seul (`ecluse_core`) ne change pas,
ni aucun fichier de prédiction des autres corpus (tous identiques octet pour octet
avant et après).

**P2-291 (24 novembre 2026)** : le tableau de bord suit les phrases signalées
« nombre dicté non reconnu » à tort, par `Ecluse.redact` (chemin du produit), sur
trois témoins sans entité annotée : durci (630, graine 42), neuf (630, graine 43,
`generate_corpus_mots_nombres_dur.py --seed 43`) et d'origine (300). Valeurs
courantes : **0 / 630, 0 / 630, 0 / 300**. Avant P2-282 (rejoué avec le
`nombres_dictes.dart` du commit parent) : 49, 41 et 0 phrases signalées, aucune
masquée. Aucun autre chiffre du tableau de bord ne change (sortie complète
comparée ligne à ligne avant et après, hors numéro de commit).

## Identifiants d'entreprise annotés `siren` au banc (P2-261, 23 novembre 2026)

Décision du 23 novembre, point 8 : SIREN, SIRET et numéro de TVA, que Écluse
masque à dessein, sont annotés `siren` ; le texte des corpus ne change pas
(empreinte SHA-256 des 1 000 textes identique, v3 `7405d819…` et extended
`3e5dcc37…`). Corpus v3 : 943 entités (871 + 72 `siren`) ; extended : 1 033
(795 + 238). **Ce qui change dans ce fichier** : les totaux « tous types » du
**moteur seul** (`run_ecluse.dart`, ce n'est pas ce que reçoit le LLM) ; la
ligne « types communs » est la comparaison principale avec Presidio.

| Mesure (moteur seul, graine 42) | Avant | Après |
|---|---|---|
| v3, tous types, strict | 92,4 % / 100 % / 96,0 % (871 TP, 72 FP) | 100 % / 100 % / 100 % (943 TP, 0 FP) |
| v3, types communs | — | 100 % / 100 % / 100 % (871 TP) |
| v3, ligne `siren` | 0 TP, 72 FP | 72 TP, 0 FP, 0 FN |
| témoin flou, `entites predites` (`Ecluse.redact` ; 216 sur chacun des corpus témoins de 400 documents : ligne « SIRET … TVA … » seule) | 216 | **0** |
| v3 à 60 colonnes, tous types, précision / F1 / FP | 90,7 % / 89,8 % / 79 | 99,2 % / 94,2 % / 7 |
| v3 à 90 colonnes, tous types, précision / F1 / FP | 91,8 % / 94,3 % / 75 | 99,7 % / 98,4 % / 3 |

Les FP restants à 60 et 90 colonnes (7 et 3) sont des RPPS lus dans la fin d'un IBAN coupé (cause connue, inchangée). Le témoin flou « rien à masquer » perdait 216 prédictions sur la seule ligne
« SIRET … TVA … » ; elle est remplacée par une ligne sans donnée personnelle
(aucun tirage touché, les autres variantes sont inchangées). Les chiffres de
`## SIREN masqués comme FINESS` (42 / 42, 383 / 400, etc.) sont inchangés :
`score_siren_finess.py` continue de mesurer les 42 SIREN, désormais annotés.

## Signalement des identifiants dictés recouverts en partie (P2-281, 24 novembre 2026)

Chemin mesuré : **`Ecluse.redact`** (ce que reçoit le LLM), par
`bench/mesure_seuil_signalement.sh` au seuil 9 (inchangé). Défaut : une suite
dictée touchée par une entité (souvent un `iban` posé sur le début d'un IBAN
abîmé) était jugée traitée en entier ; le reste partait en clair sans
avertissement. Correction : la suite n'est « recouverte » que si les entités
couvrent toutes ses lettres (`_suitesNonReconnues`).

| Identifiants dictés abîmés (2 420 par façon) | « rien » avant | « rien » après |
|---|---:|---:|
| mot perdu (NIR 6 / IBAN 3) → (NIR 4 / IBAN 0) | 9 | 4 |
| clé fausse (NIR 1 / IBAN 6) → (NIR 0 / IBAN 0) | 7 | 0 |

Masqués : inchangés (1 433 et 2 034). Témoin durci (630) : 0 masquée, 49
signalées à tort avant et après ; témoin d'origine (300) : 0 / 0. Rien n'est
masqué de plus ou de moins : seul l'avertissement change.

## Dictée : identifiants dits en lettres (P2-160)

Corpus v3 (1 000 documents, 943 identifiants depuis le 23 novembre, 826 avant, 778 avant le 22) transcrits sans audio par
`bench/generate_corpus_transcrit.py` : les deux variantes d'origine (sorties
**identiques octet pour octet** après P2-160) et quatre variantes de dictée
(`agent/specs/P2-155.md` § 2) : `double_triple` (« double zéro », « triple
neuf », chiffre par chiffre), `regional` (« septante », « huitante », « nonante »,
par groupes), `zero_o` (« o six »), `sans_traits_union` (« quatre vingt treize »,
par groupes). P2-160 : aucun détecteur modifié (défaut d'abord) ; P2-267 : seconde vue
des nombres dictés (voir plus bas).

**P2-267 (23 novembre 2026, soir)** : seconde vue « lettres → chiffres »
(`packages/ecluse_redact/lib/src/nombres_dictes.dart`), branchée dans
`Ecluse.redact` seulement ; le moteur seul (`ecluse_core`, `run_ecluse.dart`) ne la
connaît pas et reste à 0 % sur ces variantes. Les cinq variantes dictées sont
lues par `Ecluse.redact` ; la colonne « avant » est la mesure de `main` avant
P2-267.

Deux chemins, à ne pas confondre. « Rappel » = identifiant entièrement couvert
par une détection quel qu'en soit le type ; « fuite » = part des caractères
d'identifiant (blancs exclus) couverts par aucune détection.

| Variante | **`Ecluse.redact`** (ce que reçoit le LLM) : rappel avant → après | fuite au caractère avant → après | moteur seul (`ecluse_core`) : rappel |
|---|---:|---:|---:|
| sans ponctuation (chiffres) | 943/943 → 943/943 | 0,0 % → 0,0 % | 100 % (0 FP depuis P2-261) |
| en lettres (d'origine) | 23/943 → 934/943 (99,0 %) | 97,8 % → 0,1 % | 0 % |
| double / triple | 18/943 → 935/943 (99,2 %) | 98,0 % → 0,1 % | 0 % |
| septante / huitante / nonante | 32/943 → 937/943 (99,4 %) | 97,4 % → 0,0 % | 0 % |
| zéro dit « o » | 25/943 → 937/943 (99,4 %) | 97,7 % → 0,0 % | 0 % |
| traits d'union perdus | 34/943 → 937/943 (99,4 %) | 97,4 % → 0,0 % | 0 % |

Par type après P2-267 (fuite au caractère, `Ecluse.redact`, pire des cinq
variantes dictées) : NIR 0,0 %, RPPS 0,0 %, IBAN 0,0 %, SIREN 0,0 %, FINESS 1,1 %
(avant P2-271, 6 à 9 FINESS sur 129 n'étaient pas couverts en entier ; depuis
P2-271, 129 / 129 sur chaque variante : un nom d'établissement
détecté juste avant (« ch de metz finess ») absorbe les premiers mots dictés et
l'emporte au tri des chevauchements, de 1 à 17 caractères de l'identifiant restent
en clair). Plafond de GO des décisions du 23 novembre : 5 % par type et par
variante, tenu partout. Les lettres épelées d'un IBAN (« fr … h … ») et la lettre
d'un NIR corse (« douze a ») sont recopiées dans la lecture ; les lettres d'IBAN
épelées de façon plus libre, les corrections du locuteur et les erreurs de
transcription restent hors périmètre (`LIMITES.md`). Avant P2-267, les rares
identifiants « couverts » étaient des FINESS recouverts par une détection de type
**établissement** (23 sur 23 sur la variante d'origine) : aucune variante n'était
lue comme identifiant.

Seuils (point 2 des décisions) : K = 6 mots-nombres consécutifs, K = 3 derrière un
mot-clé d'identifiant. Mesure faite en faisant varier K sur les cinq variantes
(fuite au caractère par type, pire variante ; mesuré avant la lecture de la lettre
du NIR corse, d'où 0,6 % de NIR sur les lignes autres que 6 / 3 ; témoin « mots-nombres » : 0
prédiction dans chaque cas) :

| K / K derrière mot-clé | FINESS | SIREN | RPPS | NIR | IBAN |
|---|---:|---:|---:|---:|---:|
| 4 / 3 | 1,1 % | 0,0 % | 0,0 % | 0,6 % | 0,0 % |
| **6 / 3 (retenu)** | 1,1 % | 0,0 % | 0,0 % | 0,0 % | 0,0 % |
| 8 / 3 | 3,2 % | 5,5 % | 0,4 % | 0,6 % | 0,0 % |
| 10 / 3 | 65,4 % | 46,8 % | 5,3 % | 0,6 % | 0,0 % |
| 6 / 2 et 6 / 4 | identique à 6 / 3 | | | | |

Le témoin ne départage pas 4 de 6 : le faux accord est écarté par la clé de contrôle
(NIR, IBAN) ou par le mot-clé (RPPS, FINESS, SIREN : Luhn seul), pas par K. K = 6 suit la spec
(un « un » ou un « six » isolé ne déclenche rien) ; 8 et 10 perdent des FINESS
et des SIREN, dont la dictée est courte.

Témoin « mots-nombres » (`bench/generate_corpus_mots_nombres.py`, 300 phrases
synthétiques sans identifiant, dont 150 avec au moins 6 mots-nombres
consécutifs, aucune entité annotée) : **0 prédiction** par `Ecluse.redact`, avant
comme après P2-267. Un premier essai sans mot-clé pour RPPS et FINESS avait
donné 7 prédictions à tort (« cinq, six, sept, huit, neuf, dix, onze, douze » lu
comme un RPPS de Luhn valide ; « huit cent quatre-vingt-dix-neuf mille neuf cents »
lu comme un FINESS) : c'est pourquoi une validation par Luhn seul ne vaut que
derrière un mot-clé. Tous les autres corpus du dépôt donnent des prédictions
**identiques octet pour octet** avant et après (75 fichiers de prédiction
comparés, dont les moteurs seuls ; seuls les 5 fichiers `pred_redact_*` des
variantes dictées changent).

## Entités floues (corpus flous v2, 400 documents chacun)

Fuite au caractère (part des caractères annotés restés en clair).

| Corpus | nom | adresse | établissement | **global** | FP témoin | Restaurations non identiques¹ |
|---|---:|---:|---:|---:|---:|---:|
| réaliste | 27,7 % | 0 % | 0 % | **7,5 %** | | 0 |
| adversarial | **11,0 %** (13,9 % avant P2-220) | **0 %** (1,9 % avant P2-164) | 0 % | **5,3 %** (6,7 %) | | 62 (61) |
| témoin | | | | | **0** | 0 |
| réaliste en minuscules | 30,0 %⁴ | 0 % | 0 % | **8,1 %** | | 0 |
| adversarial en minuscules | 14,1 %⁴ | 0 % | 0 % | **6,8 %** | | 61³ |
| témoin en minuscules | | | | | **0** | 0 |
| réaliste en capitales | 30,0 %⁴ | 0 % | 0 % | **8,1 %** | | 0 |
| adversarial en capitales | 14,1 %⁴ | 0 % | 0 % | **6,8 %** | | 55 |
| témoin en capitales | | | | | **0** | 0 |
| faux amis prénoms (P2-124) | | | | | **0** | 0 |
| réaliste en casse de phrase (P2-138) | 30,0 %⁴ | 0 % | 0 % | **8,1 %** | | 0 |
| adversarial en casse de phrase (P2-138) | 16,8 %⁴ | 0 % | 0 % | **8,1 %** | | 61³ |
| témoin en casse de phrase (P2-138) | | | | | **0** | 0 |

¹ Harmonisation des re-mentions à la restauration (`LIMITES.md` § 5.3, point 5
de l'essentiel) : compromis documenté, pas une corruption.
³ 6 avant P2-139 : les noms en ordre « nom prénom » désormais détectés en
minuscules (« perrot olivier » puis « olivier perrot ») reçoivent un seul
jeton et sont restaurés sous la première graphie, comme en casse ordinaire
(61). Vérifié document par document le 7 novembre : seul l'ordre des mots
change, longueur et contenu identiques.

Sur le réaliste d'origine, les 27,7 % des noms sont la civilité laissée en
clair volontairement (`bench/leak_hors_civilite.py`, P2-12).

⁴ Depuis P2-145, la civilité de genre reste en clair aussi en minuscules et
en capitales (avant : 2,2 % réaliste, 5,9 % adversarial, 9,0 % adversarial en
casse de phrase). La hausse est **la civilité seule** : hors civilité, la
fuite des noms est inchangée sur le réaliste (185 caractères) et a baissé sur
l'adversarial grâce aux patronymes repris seuls (P2-144 : 5,9 % → 5,7 % avant
le retrait de la civilité). Restaurations³ : +3, patronymes désormais
détectés et harmonisés sur la forme complète.

### Option `prenomsInsee` (P2-149, désactivée par défaut)

Mêmes corpus, option active au seuil par défaut (20 naissances), mesurée avec
P2-149 (`run_redact_bench.dart --prenoms-insee`, `run_dossiers_bench.dart
--prenoms-insee`). Seules les lignes qui changent :

| Corpus | nom | **global** | Restaurations non identiques |
|---|---:|---:|---:|
| adversarial | 13,9 % → **8,3 %** | 6,7 % → **4,0 %** (7,2 % → 4,4 % avant P2-164) | 61 → 58 |

Noms de l'adversarial hors civilité : 572 → **0** caractère
(`leak_hors_civilite.py`) ; les 8,3 % restants sont la civilité. Réaliste,
témoins, faux amis, variantes de casse et dossiers : identiques à l'option
désactivée. Prose des `.md` du dépôt (`run_prenoms_insee_prose.dart`) :
6 nouvelles détections, toutes de vrais noms, après l'exclusion de « France
Travail » et « Ange Gardien » (P2-150 ; `agent/specs/P2-148.md` § 6).

## Quasi-identifiants (`ecluse_reid`, corpus QI, 400 documents)

| Corpus | âge P / R | lieu P / R | profession P / R | Non couverts (âge / lieu / prof.) |
|---|---|---|---|---|
| réaliste | 100 / 100 % | 88,2 → **100 %** / 100 % | 100 / 100 % | 0 / 0 / 0 % |
| adversarial | 100 / **100 %** (95,5 % avant P2-159) | 92,3 → **100 %** / 100 % | 100 / 96,2 → **100 %** | **0** (12,7 avant P2-159) / 0 / 2,0 → **0 %** |
| témoin | 412 extractions à tort, 337 documents sur 400 ; **57 / 57 après P2-136, 0 après P2-142** (inchangé par P2-175) | | | |
| témoin « durées » (P2-165) | 400 extractions à tort sur 400 documents ; **53 après P2-165** (la seule forme « fêtera ses N ans », inchangé par P2-175) | | | |

Identique à `bench/README.md` (P2-03b) au commit `d85fb84` ; témoin corrigé
ensuite par P2-136 (durées, communes-mots courants), réaliste et
adversarial inchangés ; âges en lettres et tranche « de N à M ans » lus par
P2-159 (adversarial : 12,7 % → 0 % d'âges non couverts, 15 âges en lettres).
Chemin : `ecluse_reid` seul (`run_reid_bench.dart`), pas `Ecluse.redact` (voir
« Quasi-identifiants par `Ecluse.redact` » ci-dessous pour le chemin produit).
Le témoin « durées » (400 phrases sans âge : « deux ans plus tard », « au bout
de 5 ans », « un contrat de trois ans », « dix ans d'ancienneté », en lettres
et en chiffres) mesure les durées lues à tort comme un âge : 400 → 53 par
P2-165, réaliste et adversarial inchangés (rappel d'âge 100 %). La
ligne « Généralisation appliquée » de l'adversarial en découle : ces 15
documents ont désormais un âge (sur les 385 autres, sortie identique, vérifié).

### Lieux à tort et professions manquées (P2-175)

Constat du 13 novembre : les 43 et 33 lieux à tort (précision 88,2 % et
92,3 % ci-dessus) étaient tous un patronyme homonyme d'une commune de la
référence publique (ex. « Chevrier », Haute-Savoie) extrait derrière une
civilité ou un métier (« Monsieur Chevrier réside à Lille » lisait à tort
« Chevrier » comme un second lieu). Les 7 professions manquées de
l'adversarial (sur 183) étaient des abréviations ou graphies sans accent :
« pneumo » (3), « gynéco » (3), « pediatre » sans accent (1).

Mesure avant → après (`ecluse_reid` seul) : précision lieu 88,2 % → **100 %**
(réaliste), 92,3 % → **100 %** (adversarial) ; rappel profession 96,2 % →
**100 %** (adversarial). Témoins inchangés (0 et 53). Correction : un mot
capitalisé juste après une civilité, un titre ou un couple article + nom
commun de métier (hors noms de lieu comme « commune », « village ») n'est
plus lu comme un lieu ; « pneumo » et « gynéco » (table dédiée) et la forme
sans accent des mots-clés de profession existants sont désormais lus par
`_professionSpans`, pas par `extractProfession` (qui compterait « pneumo »
deux fois dans « pneumologue »). Aucune commune réelle n'est perdue : les cas
contre-exemples (« Mme Verdier habite Chevrier », « il connaît le village
Chevrier », etc.) restent extraits (test dédié). Effet en cascade attendu sur
la « Généralisation appliquée » : les 7 professions désormais extraites sur
l'adversarial y gagnent une suggestion (111 → 118 documents avec suggestion,
vérifié document par document).

### Quasi-identifiants par `Ecluse.redact` (P2-175, premier volet)

Nouvelle ligne de tableau de bord : jusqu'ici, la ligne QI ne mesurait que
`ecluse_reid` seul (ce que l'extraction sait lire dans un texte déjà en
clair), jamais ce que `Ecluse.redact` laisse réellement partir. Mesure
(`score_qi_redact.py`) : le patronyme de la personne reste-t-il en clair une
fois les entités prédites par `Ecluse.redact` retirées du texte, sur les
corpus réaliste et adversarial (`generate_corpus_qi.py`) ?

| Corpus | Documents avec patronyme en clair |
|---|---:|
| réaliste | 0 / 400 |
| adversarial | **29** / 400 |

Sonde du 13 novembre (compte rendu de session, jetable, non versionnée) :
0 / 2 sur 400. Chiffre non reproduit à l'identique sur l'adversarial (29 au
lieu de 2) ; la cause est la même dans les deux mesures et n'est pas
corrigée ici (hors périmètre de ce volet) : un patronyme qui suit un métier
**hors périmètre** d'`ecluse_reid` sans civilité (« L'infirmière Chevrier »,
« Le kinésithérapeute Marchand »...) n'est pas masqué par `NameDetector`, qui
ne déclenche que sur une civilité ou un titre professionnel d'un ensemble
fermé (Dr, Pr, Me...), jamais sur un nom de métier quelconque. Vérifié : les
29 documents correspondent tous à ce cas (aucun autre patronyme en clair). À
signaler au mainteneur comme écart de mesure ; une correction éventuelle de
`NameDetector` reste une tâche à part (voir `LIMITES.md`).

## Généralisation appliquée (P2-92, P2-102, P2-116, P2-132)

| Corpus | Avec suggestion | Refus | F médian avant → après 1er tour | Bande après 1er tour |
|---|---:|---:|---|---|
| QI réaliste | 170 | 0 | 74,0 → 2 002,0 | faible 170 |
| QI adversarial | 118 (111 avant P2-175, 109 avant P2-159) | 0 | 7,0 → 2 320,0 (5,0 → 2 320,0 avant P2-175) | faible 110, moyen 7, élevé 1 |
| QI témoin | 0 | 0 | — | — |
| lieu (810 documents) | 24 | 0 | F recalculé = F simulé (24/24) | élevé 1, moyen 20, faible 3 |

## Dossiers (cohérence des jetons, avec `Dossier`)

| Corpus | Collisions | Fausses fusions | Restaurations non identiques |
|---|---:|---:|---:|
| réaliste | 0 / 557 | 0 / 935 | 0 / 397 |
| adversarial | 7 / 455 (1,5 %) (445 avant P2-220) | 7 / 606 (1,2 %) (596) | 52 / 398 (13,1 %) |
| témoin | 0 / 757 | 0 / 757 | 0 / 396 |

Variantes de casse (P2-140, P2-144, P2-145 ; `variantes_casse.py`, `_mixte` =
une casse par document, en rotation dans le dossier) :

| Corpus | Cohérence nom | Noms non détectés (avant P2-144) | Restaurations non identiques |
|---|---:|---:|---:|
| réaliste en minuscules | 30 / 160 | 4 (116) | 0 / 397 |
| réaliste en capitales | 8 / 154 | 28 (104) | 0 / 397 |
| réaliste à casse mixte | 18 / 161 | 0 (88) | 95 / 397⁵ |
| adversarial en minuscules | 36 / 128 | 10 (47) | 52 / 398 |
| adversarial à casse mixte | 24 / 128 | 8 (43) (12 avant P2-220) | 94 / 398⁵ |
| témoins (toutes casses) | 0 / 129 | 0 | 0 / 396 |

⁵ Un jeton garde une seule graphie par dossier : 95 sur 95 (réaliste) et 40
sur 94 (adversarial) ne diffèrent que par la casse ; le reste est
l'harmonisation déjà comptée en casse uniforme.

## Pathologies (P2-112 à P2-135, table validée P2-110)

Repérage, mentions rattachées à une personne :

| Corpus | Précision | Rappel | FP témoin |
|---|---:|---:|---:|
| indices (397 mentions) | 100 % | 100 % | 0 |
| variantes (300, adjectifs et négations) | 100 % | 100 % | 0 |
| formes libres (120) | 100 % | 100 % | — |

Masquage des maladies rares (P2-143, `run_maladies_rares_bench.dart`) :

| Mesure | Avant | Après |
|---|---:|---:|
| Mentions rares du corpus indices masquées | 0 / 51 | 51 / 51 |
| Pathologies fréquentes masquées (hors mucoviscidose, drépanocytose) | 0 | 0 |
| Masquages dans le témoin | 0 | 0 |
| Échantillon Orphanet (300, graine 42), rattachées ou personne nommée | 0 / 300 | 276 / 300 |
| Échantillon Orphanet, niées ou sans personne | 0 / 300 | 0 / 300 |

## Identifiant suivi d'une date, d'un âge ou d'un nombre (P2-174)

Témoin `bench/generate_corpus_identifiant_suivi.py` (graine 42) : 4 800
documents, 100 par combinaison de type (NIR, RPPS, IBAN, FINESS), de suite
(date en chiffres, date en lettres, âge, quantité) et de séparateur (espace,
virgule, retour à la ligne). Identifiants valides fabriqués (clés calculées),
écrits dans les styles du corpus v3 (collé, groupé, pointé, blancs
irréguliers). Chemin mesuré : **`Ecluse.redact`** (ce que reçoit le LLM),
scoreur `bench/score_identifiant_suivi.py`. « Non couvert » = au moins un
caractère de l'identifiant hors de toute détection (une fuite) ; « type
faux » = couvert sous un autre type ; « suite avalée » = la date, l'âge ou le
nombre voisin pris dans la détection de l'identifiant.

| | avant P2-174 | après P2-174 |
|---|---:|---:|
| Identifiants non couverts (4 800) | **804** | **1** |
| dont FINESS (1 200) | 312 | 1 |
| dont IBAN (1 200) | 290 | 0 |
| dont NIR (1 200) | 202 | 0 |
| dont RPPS (1 200) | 0 | 0 |
| Type faux (non couverts compris) | 863 | 2 |
| dont FINESS couvert mais lu comme RPPS | 55 | 0 |
| Suite avalée | 72 | 2 |
| Documents en défaut | 863 | **2** |
| Séparateur virgule (1 600) | 0 | 0 |
| Séparateur espace (1 600) | 439 | 1 |
| Séparateur retour à la ligne (1 600) | 424 | 1 |

Avant, les non couverts étaient les identifiants à blancs irréguliers et les
FINESS groupés collés à un nombre voisin (reste connu de P1-19, jamais
chiffré). Les deux documents restants : un FINESS groupé suivi de « 1250
jours », où un bloc de onze chiffres à cheval sur les deux passe Luhn (les
deux premiers chiffres du FINESS restent en clair) ; un RPPS suivi de « 1250
jours », lu comme un NIR à clé valide par hasard (tout est masqué). Détail et
restes dans `LIMITES.md` (« Identifiant suivi d'une date… »).

Effet sur le reste du tableau de bord : **une seule ligne change**, par le
**moteur seul** (pas `Ecluse.redact`) : corpus structurel à 90 colonnes, faux
positifs RPPS 2 → 3 (précision RPPS 98,8 % → 98,2 %, total 94,5 % → 94,3 %).
C'est la fin d'un IBAN à blancs irréguliers coupé par un retour à la ligne,
que le moteur seul ne lit pas comme un IBAN et dont le dernier bloc est
maintenant lu comme un RPPS. Rappels inchangés partout ; v3 d'origine :
toujours 42 faux positifs (FINESS/SIREN).

## Identifiant derrière un libellé fort : clé fausse, O/l d'OCR, ligne vide (P2-194)

Témoin `bench/generate_corpus_libelle_fort.py` (graine 42, `--n 50`) : 3 000
documents synthétiques (clés calculées), scoreur `bench/score_libelle_fort.py`.
Chemin mesuré : **`Ecluse.redact`** (ce que reçoit le LLM), pas le moteur
seul. Il mesure pour la première fois la voie de P2-188 (clé fausse) et de
P2-191 (O pour 0, l ou I pour 1, ligne vide), que seuls des tests unitaires de
`IdentifiantCleInvalideDetector` couvraient : « tableau de bord inchangé » ne
disait rien sur elle.

- **1 800 positifs** : 6 libellés (NIR, « N° de sécurité sociale », « numéro
  SS », IBAN, RPPS, ADELI) x 6 variantes (`cle_juste`, `cle_fausse`,
  `ocr_zero`, `ocr_un`, `ligne_vide`, `ocr_et_ligne_vide`) x 50. « En clair » =
  au moins un caractère de l'identifiant (hors blancs) sous aucune détection.
- **1 200 négatifs** (aucune entité annotée) : `libelle_seul` (« IBAN : voir
  pièce jointe »), `non_communique`, `mot_ordinaire` (« RPPS du praticien »),
  `nombre_sans_libelle` (nombre de forme d'identifiant, clé fausse, parfois
  avec des lettres d'OCR, sans libellé), 6 libellés x 50 chacun.

État après P2-199 (au départ, P2-194, `main` au commit `b3b6d8e` : 50 positifs en
clair sur chacune des quatre cases ADELI OCR et ligne vide, 0 ailleurs) :

| Positifs en clair, sur 50 par case | cle_juste | cle_fausse | ocr_zero | ocr_un | ligne_vide | ocr_et_ligne_vide |
|---|---:|---:|---:|---:|---:|---:|
| NIR, « N° de sécurité sociale », « numéro SS » (3 x 50) | 0 | 0 | 0 | 0 | 0 | 0 |
| IBAN | 0 | 0 | 0 | 0 | 0 | 0 |
| RPPS | 0 | 0 | 0 | 0 | 0 | 0 |
| ADELI | 0 | 0 | 0 | 0 | 0 | 0 |

Total : **0 identifiant positif sur 1 800 en clair** (200 au départ, tous
ADELI, `main` au commit `3b03ca1`). P2-199 a étendu à ADELI les tolérances de
P2-191 (O/o pour 0, l/I pour 1, ligne vide), derrière le libellé « ADELI »
seulement, dans `IdentifiantCleInvalideDetector`, et écarté une adresse qui
chevauche un identifiant annoncé (un cas, « ADELI 209l73939 noté » : « 73939
noté » lu comme une adresse, de confiance plus haute, laissait « 209l » en
clair). Chemin mesuré : `Ecluse.redact`. Le plafond
`PLAFOND_LIBELLE_FORT` de `bench/etat_attendu.py` est vide : zéro partout,
`etat.sh` échoue si un identifiant positif repasse en clair.

Témoins négatifs (**avant P2-252** ; depuis, voir la section « IBAN à clé fausse masqué en entier (P2-252) » ci-dessous : 53 sur 1 200) : **8 documents sur 1 200 masqués** (0 sur `libelle_seul`,
`non_communique`, `mot_ordinaire` ; 8 sur 300 `nombre_sans_libelle`). Ce sont
des collisions de hasard, jamais l'effet du libellé : une sous-suite de onze
ou neuf chiffres qui passe Luhn (lue RPPS ou FINESS), un nombre à cinq
chiffres suivi d'un mot (adresse), un IBAN dont la clé fausse redevient juste
par la lettre d'OCR du corps. Le libellé fort n'ajoute donc aucun masquage
sur ses faux amis.

**Confiance et avertissement « à vérifier » (P2-203, mesure seule, aucun
détecteur modifié).** `run_redact_bench.dart --confiance` écrit pour chaque
entité sa `confidence` et, par document, `a_verifier` (un avertissement de
`Ecluse.redact` contient « à vérifier ») ; `score_libelle_fort.py` en tire les
lignes ci-dessous (aucun texte ni valeur). Chemin : **`Ecluse.redact`**.
`main` au commit `3b03ca1`, même témoin (3 000 documents, graine 42). Pour un
positif, la confiance est la plus haute parmi les détections qui touchent
l'identifiant.

| Positifs, confiance du masquage | 0,3 | 0,55 | 0,6 | 0,9 | 0,95 | 1 | aucune |
|---|---:|---:|---:|---:|---:|---:|---:|
| tous (1 800) | 1 250 | 1 | 50 | 50 | 50 | 200 | 199 |
| `cle_juste` (300) | 0 | 0 | 0 | 50 | 50 | 200 | 0 |
| `cle_fausse` (300) | 250 | 0 | 50 | 0 | 0 | 0 | 0 |
| `ocr_zero`, `ligne_vide`, `ocr_et_ligne_vide` (900) | 750 | 0 | 0 | 0 | 0 | 0 | 150 |
| `ocr_un` (300) | 250 | 1 | 0 | 0 | 0 | 0 | 49 |

(« aucune » = en clair : les 200 ADELI OCR du point de départ ; le document de
confiance 0,55 est une adresse qui chevauche un ADELI, voir P2-199.)

- **Avertissement « à vérifier »** : 1 250 positifs sur 1 800 (250 sur 300 par
  variante autre que `cle_juste`, 0 sur `cle_juste`) ; **0 négatif sur 1 200**.
  Il coïncide avec les masquages à confiance 0,3 : 0 incohérence (aucun masquage
  à 0,3 sans avertissement, aucun avertissement sans 0,3), positifs et négatifs.
- **ADELI à clé fausse masqué à 0,6 : sans avertissement** (50 documents,
  `AdeliDetector`, confiance 0,6 par `LIMITES.md` § 2) alors que NIR, IBAN et
  RPPS à clé fausse (confiance 0,3) en portent un. Constat de P2-203 ;
  **corrigé par P2-204** (ci-dessous).
- **Après P2-204** (chemin `Ecluse.redact`, graine 42, même témoin) :
  avertissement « à vérifier » **1 450 → 1 500** positifs sur 1 800 au
  tableau de bord actuel (les ADELI OCR de P2-199 en portaient déjà un) ;
  `cle_fausse` 250 → **300 / 300**, soit ADELI × `cle_fausse` **0 → 50 / 300** ;
  négatifs inchangés (0 / 1 200) ; confiance 0,6 inchangée. L'invariant
  « avertissement ⇔ confiance 0,3 » ne tient plus pour ce seul cas : le
  scoreur le compte à part (`exception P2-204 … positifs 50`) au lieu de
  l'afficher comme incohérence (`incohérence … positifs 0` reste le garde-fou
  pour tout autre cas).
- Les 8 négatifs masqués sont masqués par d'autres détecteurs, de confiance 0,5
  (1), 0,55 (4), 0,9 (2) et 1 (1) : aucun à 0,3, donc aucun avertissement ; le
  libellé fort n'y est pour rien.

Non mesuré ici : les libellés « sécurité sociale » seuls ou en minuscules accentuées variées ;
les identifiants dans un tableau ou un PDF. Corpus synthétique : aucun chiffre
ne vaut fréquence réelle.

## Nombres à cinq chiffres hors adresse (P2-167)

Témoin `bench/generate_corpus_cinq_chiffres.py` (400 phrases, graine 42,
**aucune adresse annotée** : toute adresse prédite est un faux positif) :
quantités (« Commande de 70000 unités »), montants, références, lots et
dossiers, suivis d'un mot en minuscules, d'un mot à majuscule ou de rien, le
nombre ouvrant la phrase ou venant après des mots, en casse ordinaire ou en
casse de phrase. Chemin mesuré : **`Ecluse.redact`** (ce que reçoit le LLM) ;
les deux voies (détecteur seul, texte d'ombre des casses de phrase et
minuscules) sont comptées à part par `run_cinq_chiffres_bench.dart` pour dire
quelle règle produit la prédiction.

| | avant P2-167 | après P2-167 |
|---|---:|---:|
| Adresses prédites à tort (400 phrases) | 130 | **74** |
| dont voie « détecteur seul » (nombre + mot à majuscule) | 88 | 49 |
| dont voie « texte d'ombre » (nombre + nom commun, casse de phrase) | 42 | 25 |
| nombre après des mots (200 phrases) | 64 | **8** |
| nombre en tête de phrase (200 phrases) | 66 | 66 |
| montants (« euros ») et nombre sans mot suivant | 0 | 0 |

Correction : un nombre à cinq chiffres **introduit par une tournure de
quantité ou de référence** (« environ », « lot », « réf. », « n° », « total »,
« commande de », « lot de »… ; **jamais « de » seul** : « la mairie de 70000
Vesoul » reste masqué, les 8 nombres restants sont introduits par « de » seul) n'est plus pris pour un code postal sans voie. **Reste** : un nombre
en tête de phrase suivi d'un mot (« 58699 Alpha livrés ») a exactement la forme
d'un code postal en tête de ligne (« 70000 Vesoul ») ; aucune tournure ne les
sépare, ils restent masqués (66 sur 200). Reste du tableau de bord inchangé
(adresses des corpus flous comprises).

## Code postal en tête : les adresses à ne pas perdre (P2-177)

Pendant du témoin ci-dessus : `bench/generate_corpus_cp_tete.py` (432 documents,
graine 42, **une adresse annotée par document**), un code postal qui ouvre le
texte, une ligne (bloc d'adresse ou prose recoupée) ou une phrase, suivi de sa
commune puis de rien, d'une fin de ligne, d'une ponctuation ou de mots en
minuscules (« 25000 Besançon depuis 2019 »), en casse ordinaire et sans
majuscule. Chemin mesuré : **`Ecluse.redact`** (ce que reçoit le LLM). Une
adresse est « en clair » dès qu'un de ses caractères hors blancs n'est sous
aucune détection.

| | `Ecluse.redact` |
|---|---:|
| Adresses laissées en clair, en tout ou en partie (432) | **0** |
| dont suivies de mots en minuscules (108) | 0 |

**Règle candidate, simulée par le banc** (`run_cp_tete_bench.dart
--regle-candidate`, **absente de `lib/`**) : écarter une adresse prédite qui
commence par un code postal en tête et dont le nom est suivi, sur la même
ligne, d'un mot en minuscules. Les deux colonnes mesurent `Ecluse.redact`, la
règle étant appliquée à ses prédictions.

| Règle candidate | sans la règle | avec la règle (simulée) |
|---|---:|---:|
| Témoin sans adresse : prédictions à tort (400 phrases) | 74 | 8 |
| dont nombre en tête de phrase (200 phrases) | 66 | **0** |
| Corpus « code postal en tête » : adresses en clair (432) | 0 | **108** |
| dont début de texte / début de ligne / après une phrase | 0 | 36 / 36 / 36 |
| Corpus flous réaliste et adversarial : adresses en clair (159 et 155)¹ | 0 | 0 |

¹ Hors tableau de bord (rejeu à la main du même binaire sur les corpus flous
d'origine, en minuscules et recoupés à 60 et 90 colonnes ; réaliste en casse
de phrase ; 3 documents refusés à 60 colonnes, hors compte) : ces corpus n'ont aucune adresse en tête suivie d'un
mot en minuscules, ils n'exercent donc pas la perte.

**Décision appliquée (fiche P2-177)** : les deux formes ne se séparent pas
sans perte ; le masquage à tort est gardé, **aucun détecteur n'est modifié**,
la limite est écrite dans `LIMITES.md` § 5.2. Le témoin reste à 74 (66 en
tête).

## Communes : nom en partie en clair après CEDEX (P2-178, P2-180, P2-181)

Balayage des 34 875 communes du référentiel (`geo_communes.csv.gz`,
populations légales INSEE), une fois par écriture, avec « code postal +
commune + CEDEX n » (`bench/generate_corpus_cedex.py --balayage`, graine 42).
Chemin mesuré : **`Ecluse.redact`**. Une commune est « en défaut » dès qu'un
de ses caractères (ou du mot « CEDEX »/son numéro) reste en clair ; détail
par cause, longueur et forme de CEDEX dans `agent/specs/P2-178.md`.

| Écriture | Avant (P2-178, mesure) | Après P2-180 | Après P2-181 |
|---|---:|---:|---:|
| `libelle` (officiel) | 163 / 34 875 | 26 / 34 875 | **10** / 34 875 |
| `postale` | 145 / 34 875 | 145 / 34 875 | **7** / 34 875 |
| `libelle_espaces` | 901 / 34 875 | 626 / 34 875 | **15** / 34 875 |
| `capitales_tirets` | 143 / 34 875 | 14 / 34 875 | **9** / 34 875 |

**P2-180 (tâche A de `agent/specs/P2-178.md` § 7)** corrige deux causes
indépendantes de la longueur, dans `AdresseDetector` : la lettre « œ »/« Œ »
(hors des classes Latin-1 du motif de commune, « 59112 Annœullin » perdait
tout après « Ann », « 02000 Œuilly » n'était pas reconnu comme commune du
tout) et un mot qui commence comme un titre abrégé (« M », « Pr »…) suivi
d'une lettre accentuée, pris à tort pour une civilité annonçant un nom
(`\b` de Dart ne voit pas les lettres accentuées comme des lettres sans le
drapeau `unicode` : « Le **Pr**é-Saint-Gervais », « Les **M**ées »). Les
civilités réelles devant un nom (« Mme Durand », « M. Durand », « Dr Faure »,
« Me Blanc ») sont toujours suivies d'un espace ou d'un point, donc
inchangées. `postale` n'est pas concerné (sa cause dominante est la longueur,
tâche B) ; `libelle_espaces` baisse en sous-produit (il partage les deux
causes corrigées ici avec sa cause dominante, les mots de liaison absents,
non traités par P2-180).

Témoins flous à 0 prédiction à tort, reste du tableau de bord inchangé
ligne à ligne (vérifié par rejeu complet).

**P2-181 (tâche B de `agent/specs/P2-178.md` § 7)** : ce qui sépare un code
postal du mot « CEDEX », sur la même ligne, est la localité. Devant « CEDEX »
seulement, `AdresseDetector` prend jusqu'à cinq mots de plus et les mots de
liaison que le balayage avait trouvés absents (« et », « au », « à », « près »,
« devant », « di », « ès »…). **Sans « CEDEX » derrière, le motif est celui
d'avant** : la correction ne masque rien de plus dans un texte sans CEDEX
(témoin ci-dessous, inchangé).

Ce balayage n'a que des adresses avec CEDEX : il ne mesure donc que ce cas.
Le corpus par longueur (`generate_corpus_cedex.py` sans `--balayage`,
5 880 adresses, **hors tableau de bord**, rejoué à la main par `Ecluse.redact`)
dit ce qui reste sans CEDEX :

| Forme (1 960 adresses chacune) | Avant P2-181 | Après P2-181 |
|---|---:|---:|
| sans CEDEX | 263 en défaut (4,1 % des caractères) | 263 (4,1 %), **inchangé** |
| « CEDEX n » | 270 (5,6 %) | **22** (0,8 %) |
| « Cedex 0n » | 294 (6,2 %) | **22** (0,8 %) |

Restent, au balayage (41 adresses, classement du scoreur) : 30 pour une
parenthèse ou un tiret isolé dans le nom (« Bors (Canton de …) », non
traité), 6 pour un mot en minuscules hors liste (« et ses environs », « es »,
« plages », « sans », « ô »), 3 autres (double espace laissé par un tiret
isolé retiré, « Bourg Madame » sans tiret : « Madame » annonce un nom) et 2 où
la fin du nom est prise par une détection de nom (la commune n'est pas en
clair, le numéro de CEDEX l'est). 15 communes distinctes sur 34 875, contre
951 à la mesure P2-178.

## Commune suivie de mots ordinaires : le sur-masquage (P2-181)

Témoin `bench/generate_corpus_commune_suivie.py` (480 documents, graine 42) :
une adresse « code postal + commune » annotée, suivie **sur la même ligne**
d'une suite qui n'en fait pas partie — mots ordinaires en capitales (« 25000
BESANCON ET ENVIRONS »), mots à majuscule (« Service des Admissions »), ou mot
de liaison (« 70000 Vesoul à 9 h », « et Besançon »). Chemin mesuré :
**`Ecluse.redact`** (`score_commune_suivie.py`). La suite masquée est du texte
ordinaire que le LLM ne reçoit plus (lisibilité perdue, **pas une fuite**) ;
l'adresse en clair, elle, serait une fuite.

| | Avant P2-181 | Après P2-181 |
|---|---:|---:|
| Documents à la suite masquée en partie (480) | 308 | 308 |
| Caractères de suite masqués | 3 739 / 6 659 (56,1 %) | 3 739 / 6 659 (56,1 %) |
| dont suite en capitales (160 documents) | 152 documents, 1 797 / 2 497 | inchangé |
| dont suite à majuscule (160) | 145 documents, 1 898 / 2 354 | inchangé |
| dont suite introduite par une liaison (160) | 11 documents, 44 / 1 808 | inchangé |
| Adresses en partie en clair | 0 | 0 |

Deux lectures :

- **Le témoin ne bouge pas** avec P2-181 (aucune suite du témoin n'est suivie
  de « CEDEX ») : c'est la condition de la fiche.
- **Le sur-masquage existait déjà** et il est fort : un mot à majuscule ou en
  capitales qui suit une commune de moins de quatre mots est pris pour la
  suite de son nom (« 70000 VESOUL SERVICE DES ADMISSIONS » est masqué en
  entier). C'est la limite connue du motif « un mot puis trois au plus », sans
  table des communes ; ce témoin la chiffre pour la première fois.

**Règle candidate mesurée et non retenue** (rejeu à la main du même binaire,
règle **absente de `lib/`**) : prolonger aussi le nom quand il va jusqu'à la
**fin de la ligne**, sans CEDEX. Par `Ecluse.redact` :

| Règle candidate « fin de ligne » | P2-181 (retenu) | avec la candidate |
|---|---:|---:|
| Corpus par longueur, sans CEDEX : adresses en défaut (1 960) | 263 | **22** |
| Témoin : caractères de suite masqués (6 659) | 3 739 | **4 858** |
| dont suite qui finit la ligne (240 documents) | 155 documents, 1 882 car. | 214 documents, 3 001 car. |
| dont suite introduite par une liaison (160) | 11 documents | 62 documents |

Elle comble la fuite sans CEDEX mais masque nettement plus de texte
ordinaire : la fiche P2-181 demande de s'arrêter là et de laisser le choix au
mainteneur.

## Communes en capitales : nom en partie en clair après CEDEX (P2-183, P2-185, P2-187)

Même balayage que ci-dessus (34 875 communes × 4 écritures, 139 500
adresses), le document **tout en capitales** (`variantes_casse.py`, branche
`capitales` d'`AdresseDetector`). Chemin mesuré : **`Ecluse.redact`** (ce que
reçoit le LLM). 0 refus. Ajouté à `etat.sh` par P2-185 (qui s'était arrêtée
sans toucher de détecteur, `agent/specs/P2-185.md`) ; la correction est livrée
par P2-187.

| | Adresses en défaut | Fuite au caractère | dont cause « déterminant initial » |
|---|---:|---:|---:|
| `main` avant P2-187 (rejoué le 15 novembre)¹ | 8 736 / 139 500 | 6,4 % (200 271 / 3 117 758) | **8 457** |
| après P2-187 | **95** | **0,1 %** (2 020) | **4** |

¹ Le tableau de P2-185 donnait 8 885 / 6,5 % (202 070) : `main` avait bougé
depuis (cause « autre » 63 aujourd'hui) ; le chiffre « avant » ci-dessus est
celui rejoué sur `main` le 15 novembre, la cause « déterminant initial »
(8 457) n'a pas changé. Autres causes après P2-187 : autre 59, ponctuation 30.

**Coût (P2-187)** : témoin `bench/generate_corpus_determinant.py` (400
phrases, graine 42, **aucune adresse annotée**), « nombre à cinq chiffres +
LE/LA/LES/L' + mots ordinaires », chemin **`Ecluse.redact`**. Toute adresse
prédite est un masquage en trop (de la lisibilité perdue ; la commune en clair
serait une fuite) :

| Phrases avec une adresse prédite (sur 200) | Avant | Après |
|---|---:|---:|
| en capitales | 26 | **107** |
| en casse ordinaire | 113 | 113 (inchangé) |

La casse ordinaire est le comportement de `main` depuis P2-167/P2-177 ;
l'essai y aligne les capitales (107 contre 113). En capitales, la « commune »
avale les mots à majuscule qui suivent : « VOIR 12345 LE SERVICE DES
ADMISSIONS. » devient « VOIR [ADRESSE_1]. ». Restent intacts : déterminant seul
(« 70000 LA »), second mot neutre (« 70000 LES DOSSIERS DU MOIS »), « 70000 LES
3 PREMIERS ».

## Communes en capitales sans « CEDEX », témoin mot neutre devant CEDEX (P2-200)

Mesure de départ avant P2-201 (`main` au commit `3b03ca1`, graine 42, aucun
détecteur modifié). Chemin mesuré : **`Ecluse.redact`** (ce que reçoit le LLM).

**Balayage sans CEDEX** (`generate_corpus_cedex.py --balayage --cedex sans`) :
mêmes 34 875 communes × 4 écritures, 139 500 adresses, tout en capitales
(`variantes_casse.py`), sans mot « CEDEX ». 0 refus.

| Balayage en capitales | Adresses en défaut | Fuite au caractère | Causes (`score_cedex.py`) |
|---|---:|---:|---|
| avec « CEDEX n » (P2-187) | 95 / 139 500 | 0,1 % (2 020 / 3 117 758) | autre 59, ponctuation 30, déterminant initial 4 |
| **sans CEDEX** (P2-200) | **338 / 139 500** | **0,1 %** (3 061 / 2 280 758) | **longueur 216, autre 60, ponctuation 30, déterminant initial 16** |

Par écriture, sans CEDEX : libellé 30, postale 168, libellé à espaces 110,
capitales à tirets 30 ; 165 communes distinctes sur 34 875 touchées sous au
moins une écriture. La cause « longueur » (216) est la commune de plus de
quatre mots, que la suite devant « CEDEX » de P2-181 couvrait ; elle n'existe
qu'ici. La cause « autre » (60) contient la classe « mot neutre en tête » de
`agent/specs/P2-196.md` (non ventilée par le scoreur). Les 338 adresses sont
de la fuite de nom de commune (lieu, pas une personne) ; aucun CEDEX en jeu.

**Témoin de faux positifs devant CEDEX** (`generate_corpus_neutre_cedex.py`,
400 phrases, graine 42, **aucune adresse annotée**), « cinq chiffres + mot
neutre (+ parenthèse, tiret) + CEDEX n » (« VIREMENT DE 70000 EUROS CEDEX 3 »),
en capitales et en casse ordinaire :

| Phrases avec une adresse prédite | Avant correction |
|---|---:|
| en capitales (sur 200) | **0** |
| en casse ordinaire (sur 200) | **0** |
| par forme de suite : mot / parenthèse / tiret | 0 / 136, 0 / 132, 0 / 132 |

Aujourd'hui la règle du mot neutre protège entièrement ce cas ; le chiffre à
suivre pour P2-201 est donc **0 → ?** (coût de la levée devant CEDEX). Témoin
construit : il dit le pire cas, pas une fréquence. Corpus synthétique.

## Communes en capitales devant « CEDEX » (P2-201)

Avant : `main` au commit `1cb1e9b` (rejoué le 16 novembre, identique à P2-200).
Après : branche `claude/P2-201-commune-capitales-cedex`. Graine 42. Chemin
mesuré : **`Ecluse.redact`** (ce que reçoit le LLM). Détecteur modifié :
`AdresseDetector` (règle du mot neutre levée quand le texte reconnu finit par
« CEDEX » ; parenthèse, tiret entouré de blancs et deux ou trois blancs admis
dans la suite devant « CEDEX »). Rien d'autre dans `lib/`.

| Mesure | Avant | Après |
|---|---:|---:|
| Balayage en capitales avec « CEDEX n » : adresses en partie en clair | 95 / 139 500 | **1** / 139 500 |
| fuite au caractère | 0,1 % (2 020 / 3 117 758) | **0,0 %** (1 / 3 117 758) |
| Balayage en capitales **sans** « CEDEX » | 338 / 139 500 | 338 (inchangé) |
| Témoin « nombre + mot neutre + CEDEX », capitales (sur 200) | 0 | **113** |
| Témoin « nombre + mot neutre + CEDEX », casse ordinaire (sur 200) | 0 | 0 |

Le reste d'une adresse en défaut après P2-201 : « SAINT M HERVE » en écriture
postale (le « M » isolé est lu comme une civilité, le numéro de CEDEX reste).
Témoin par forme de suite (mot / parenthèse / tiret) : 38 / 136, 37 / 132,
38 / 132 ; par position : 100 / 200 en tête de phrase, 13 / 200 après des mots
(les tournures de quantité « total de », « lot », « réf. » protègent le nombre) ;
par famille : quantité 64 / 204, référence 49 / 196. Témoin construit : il dit
le pire cas (une phrase par forme, toutes avec « CEDEX »), pas une fréquence.

**Changement que la fiche ne prévoyait pas** : le motif de la suite devant
« CEDEX » est partagé avec la casse ordinaire, donc le balayage **en casse
ordinaire** avec « CEDEX n » (section P2-178 ci-dessus) passe de 41 à **8**
adresses en partie en clair (`libelle` 10 → 1, `postale` 7 → 1,
`libelle_espaces` 15 → 6, `capitales_tirets` 9 → 0). C'est une amélioration de
la même règle (« devant CEDEX seulement »), pas une régression ; aucun témoin
de faux positifs en casse ordinaire ne bouge (0 / 200 au témoin ci-dessus). Le
mainteneur peut demander de la limiter aux capitales.

## Communes en capitales sans « CEDEX » : formes et coût des règles candidates (P2-206)

Mesure seulement, `main` au commit `8b516b7`, graine 42, **aucun `lib/`
modifié**. Chemin mesuré : **`Ecluse.redact`** (ce que reçoit le LLM) pour les
prédictions de départ ; les deux règles candidates sont **simulées** par
`bench/regles_candidates_communes.py` en ajoutant leur étendue aux détections
de `Ecluse.redact` (union). Une implémentation réelle règle aussi les
chevauchements avec les autres détecteurs (`resolveOverlaps`) : les chiffres
ci-dessous sont un ordre de grandeur du gain et du coût, pas la mesure d'une
implémentation. Reproduit par `bash bench/etat.sh`, section « formes et règles
candidates ».

**Ventilation des 338 adresses en défaut** (`classe_communes_capitales.py
--sans`, une seule forme par adresse, dans l'ordre E, C, D, B, A) : le total et
les cinq formes de `agent/specs/P2-205.md` sont retrouvés.

| Forme | Adresses | Communes | Exemples du référentiel |
|---|---:|---:|---|
| A plus de quatre mots | 216 | 135 | FLAVIGNY LE GRAND ET BEAURAIN |
| B mot neutre en tête (hors LE, LA, LES, L') | 57 | 15 | SON ; VERS ; SOUS PARSAT |
| C parenthèse, tiret isolé, blancs multiples | 32 | 9 | SARROUX - SAINT JULIEN |
| D déterminant puis mot neutre | 4 | 1 | LES PLACES |
| E mot-clé d'établissement dans le nom | 29 | **14** | MAS CABARDES |
| autre | 0 | 0 | |

Un écart avec la spec : E compte **14** communes ici, la spec en annonçait 15
(elle avait classé avec un script jetable). La forme E se lit sur les
prédictions : une détection de type `etablissement` recouvre l'adresse
annotée ; les autres formes se lisent sur le nom de la commune.

**Gain des règles sur le balayage** (139 500 adresses ; formes A à D, 309
adresses ; la forme E n'est pas simulable, c'est un autre détecteur) :

| Règle simulée | Formes A à D en partie en clair |
|---|---:|
| aucune (`Ecluse.redact` seul) | 309 |
| nom exact du référentiel (plus long préfixe de la fin de ligne) | **0** |
| nom exact, ligne entière | **0** |
| fin de ligne (mots à majuscule ou de liaison) | **61** (B 57, D 4) |

Lecture : le **0** du nom exact est vrai **par construction** (le balayage est
fait avec les noms du référentiel, la règle les reconnaît tous). Il ne dit rien
de ce qui n'est pas au référentiel (abréviations « ST », « STE », fautes) : non
mesuré. « Fin de ligne » ne lève pas la règle du mot neutre, donc B et D
restent.

**Coût sur le témoin « commune suivie »** (`generate_corpus_commune_suivie.py`,
480 documents, 6 659 caractères de suite ordinaire ; caractères de suite
masqués, hors blancs ; adresse en partie en clair : 0 partout) :

| Règle simulée | Règle à toute ligne (comme P2-181) | Règle aux seuls textes en capitales¹ |
|---|---:|---:|
| `Ecluse.redact` seul | 3 739 (308 documents) | 5 379 (462 documents) |
| nom exact (préfixe ou ligne entière) | 3 739 (**+0**) | 5 379 (**+0**) |
| fin de ligne | 4 808 (**+1 069**, 363 documents) | 6 631 (**+1 252**, 476 documents) |

¹ Le témoin passé en capitales par `variantes_casse.py`, la branche où la règle
vivrait. Le sur-masquage de départ y est déjà de 462 documents sur 480 : le
témoin en capitales ne distingue presque plus rien.

Depuis P2-212 (formes sans accent des mots neutres), la colonne « capitales »
change de 3 caractères : `Ecluse.redact` seul 5 376 (au lieu de 5 379), nom exact
5 376 (+0), fin de ligne 6 631 (**+1 255**), 462 et 476 documents inchangés ; la
colonne « toute ligne » ne bouge pas. Moins de suite masquée en trop, 0 adresse
en partie en clair.

**Écart de 3 caractères expliqué (P2-237, mesure seulement).** Chemin mesuré :
`Ecluse.redact` (`run_redact_bench.dart`), témoin « commune suivie » en
capitales (`variantes_casse.py`, 480 documents, graine 42), rejoué sur le
parent de P2-212 (`d88c8b0^`) et sur `main`, document par document ; caractères
de suite masqués = caractères non blancs de la suite sous une détection.

| | Avant P2-212 | Après P2-212 |
|---|---:|---:|
| Caractères de suite masqués, 480 documents | 5 379 | 5 376 |
| Documents dont l'étendue masquée diffère | — | **3** (n° 78, 276, 312) |

- **Documents.** Les trois ont la suite « RETOUR A L EXPEDITEUR » (11 documents
  du témoin portent cette suite ; les huit autres ne changent pas, la commune y
  est trop longue pour que « A » entre dans le même passage). Pour chacun,
  l'étendue de l'adresse passe de « …commune RETOUR A » à « …commune RETOUR » :
  **un seul caractère** de moins, la lettre « A » (7 → 6 caractères de suite
  masqués), soit 3 caractères au total. Aucune autre différence de prédiction
  sur les 480 documents.
- **Règle responsable.** `MinusculesRecapitaliseDetector` (passage
  `communesSeules` autour de `AdresseDetector`, `ecluse.dart`). Il passe au
  détecteur d'adresse un texte d'ombre où chaque mot reçoit une majuscule
  initiale, sauf les mots neutres. P2-212 (#436) a ajouté la forme sans accent
  « a » aux mots neutres (`estMotNeutre`) : « A » (écriture sans accent de
  « à ») reste en minuscule dans l'ombre, la commune s'arrête avant lui. Avant,
  il était recapitalisé et avalé comme dernier mot de la commune. Sonde sur le
  texte « 90046 LONS LE SAUNIER RETOUR A L EXPEDITEUR » : `AdresseDetector` seul
  20–48 avant et après ; avec l'ombre, 20–50 avant, 20–48 après.
- **Verdict : masquage plus juste, ni fuite ni perte.** « A » est une préposition
  ordinaire, pas une partie de l'adresse. L'adresse annotée reste entièrement
  couverte (0 adresse en partie en clair sur les 480 documents, avant et
  après). Le mot « RETOUR » reste masqué dans les trois cas (sur-masquage connu
  de la colonne « capitales », non traité ici). Aucune correction.
- **Non mesuré.** Les prédictions de `Ecluse.redact` seul : la colonne « fin de
  ligne » simulée (6 631) n'a pas été recalculée ici.

La règle « fin de ligne » de P2-181 avait été rejouée à la main et n'était pas
versionnée : la lecture écrite ici donne 4 808 là où P2-181 avait noté 4 858
(écart de 50 caractères, non expliqué, la règle d'origine n'est pas
retrouvable). Le nom exact ne masque **rien de plus** sur ce témoin : le nom
exact est « VESOUL », que le motif à quatre mots masque déjà avec sa suite.

**Coût sur des témoins sans adresse annotée** (toute adresse en plus est un
masquage en trop, de la lisibilité perdue ; la règle ne vit que dans les
capitales) :

| Témoin | Capitales : adresses prédites, `Ecluse.redact` seul | + nom exact (préfixe) | + nom exact (ligne) | + fin de ligne |
|---|---:|---:|---:|---:|
| noms de communes de forme neutre (`generate_corpus_commune_neutre.py`, 200 en capitales) | 0 / 200 | **+200** | **+100** | +0 |
| cinq chiffres (P2-167) | aucun texte en capitales : rien de mesuré | | | |
| déterminant (P2-187, 200 en capitales) | 107 / 200 | +1 | +0 | +96 |

Le témoin de formes neutres est **construit** : chaque phrase contient par
construction un nom du référentiel après cinq chiffres (« 08061 SON »), il dit
le pire cas du nom exact (le coût de lever la règle du mot neutre pour ces 15
communes), pas une fréquence. Le +1 du témoin « déterminant » est « LA
REUNION », commune du référentiel (« STOCK DE 59477 LA REUNION DE SERVICE ») :
un cas réel de faux positif du nom exact, sur 200. **Non mesuré** : la
fréquence de ces tournures dans du texte réel, la part des écritures hors
référentiel, l'interaction avec les autres détecteurs.
## `EtablissementDetector` : frontière de mot et étendue limitée au nom (P2-207)

Avant : `main` au commit `8b516b7` (rejeu du 16 novembre). Après : branche
`claude/P2-207-etablissement-frontiere-mot`. Graine 42. Chemin mesuré :
**`Ecluse.redact`** (ce que reçoit le LLM). Modifié : `EtablissementDetector`
(frontière de mot à gauche écrite `(?<![\wÀ-ÿ])`, `\b` ne connaissant pas les
lettres accentuées : « CH » trouvé dans « BUËCH ») et le recollage de fin de
ligne de `coupures_de_nom.dart` (même frontière ; les débuts de phrase de la
liste fermée se lisent aussi en capitales : « MERCI » n'est plus la suite du
nom, « DE », « DES », « SUR » le restent). L'étendue masquée ne déborde plus
sur la ligne suivante (« MAS GRENIER⏎MERCI DE VOTRE RETOUR »).

| Mesure (balayage en capitales sans CEDEX, 139 500 adresses) | Avant | Après |
|---|---:|---:|
| Adresses en partie en clair | 338 | **309** |
| Fuite au caractère | 0,1 % (3 061 / 2 280 758) | 0,1 % (2 886) |
| Cause « déterminant initial » | 16 | **4** |
| Cause « autre » | 60 | 59 |

Les 29 adresses de la forme E (`agent/specs/P2-205.md` § E) sont corrigées ; les
309 restantes sont les formes A (216), B (57), C (32) et D (4), non touchées.
**Reste du tableau de bord inchangé** : `bash bench/etat.sh` rejoué en entier
sur `main` et sur la branche, seules ces quatre lignes diffèrent (corpus
flous d'établissements, mises en page, balayage avec CEDEX, témoins de
sur-masquage : identiques, donc aucun établissement du corpus perdu). Le
corpus d'établissements est celui des corpus flous du tableau de bord
(`bench/etat.sh`, sections « flou » et « mise en page »).
## Communes en capitales sans « CEDEX » : règle « nom exact du référentiel » (P2-214)

Avant : `main` au commit `bd7d24b` ; après : P2-214. Graine 42. Chemin mesuré :
**`Ecluse.redact`** (ce que reçoit le LLM). La règle est dans `lib/`
(`AdresseDetector`, texte tout en capitales) ; elle lit une table de 261 noms
écrite dans le paquet (`communes_nom_exact.dart` : 251 noms de cinq mots ou
plus, 9 à parenthèse ou tiret isolé, « LES PLACES »), générée depuis le
référentiel versionné par `tools/build_communes_nom_exact.py`. Les 15 communes
de forme B (mot neutre en tête) n'y sont pas, par décision du 16 novembre.

| Mesure (`Ecluse.redact`) | Avant | Après | Simulation de P2-206 |
|---|---:|---:|---:|
| Balayage capitales sans CEDEX, adresses en partie en clair | 309 / 139 500 | **57 / 139 500** | 0 (forme B comprise) |
| dont forme A (plus de quatre mots) | 216 | **0** | 0 |
| dont forme B (mot neutre en tête), laissée de côté | 57 | 57 | 0 |
| dont forme C (parenthèse, tiret isolé, blancs) | 32 | **0** | 0 |
| dont forme D (« LES PLACES ») | 4 | **0** | 0 |
| Fuite au caractère, même balayage | 2 886 / 2 280 758 | 921 / 2 280 758 | |
| Balayage capitales avec « CEDEX n » | 0 / 139 500 | 0 / 139 500 | |
| Témoin commune suivie (P2-181), caractères de suite masqués | 3 739 / 6 659 | 3 739 / 6 659 | +0 |
| Témoin cinq chiffres (P2-167), phrases à adresse prédite | 74 / 400 | 74 / 400 | +0 |
| Témoin déterminant (P2-187), capitales | 107 / 200 | 107 / 200 | +1 (« LA REUNION ») |
| Témoin mot neutre devant CEDEX (P2-200), capitales | 113 / 200 | 113 / 200 | |
| Témoin commune de forme neutre (P2-206), capitales | 0 / 200 | **8 / 200** | +200 |
| Courriers en capitales (P2-210), lignes masquées en trop | 35 / 3 185 | 35 / 3 185 | |

Deux écarts avec la simulation, tous deux dans le bon sens et expliqués par la
table. **« LA REUNION »** : la simulation comparait à tout le référentiel ; la
table ne contient que les noms que le motif ne lit pas seul, et ce nom de deux
mots n'en est pas. **Témoin de forme neutre, 8 / 200** : ce sont les phrases
du seul nom de forme D, « LES PLACES » (« VIREMENT DE 99307 LES PLACES EFFECTUE
LUNDI », 8 de ses 14 phrases en capitales ; les 6 autres suivent une tournure
de quantité) ; les 192 autres phrases portent un nom de forme B, hors de la
règle. C'est du masquage en trop, pas une fuite.

Le « 0 » des formes A, C et D est vrai par construction : le balayage écrit
les noms du référentiel, et la règle les lit. Une écriture hors référentiel
(« ST », faute) n'est pas mesurée ici (P2-215). Les lignes « règles simulées »
de `etat.sh` (P2-206) repartent maintenant de 57 au lieu de 309. Reste du
tableau de bord : identique à `main`, ligne pour ligne.

## « SAINT M HERVE » : le « M » isolé n'est pas une civilité (P2-208)

Avant : `main` au commit `8b516b7` (rejeu du 16 novembre). Après : branche
`claude/P2-208-saint-m-civilite`. Graine 42. Chemin mesuré : **`Ecluse.redact`**
(ce que reçoit le LLM). Modifiés : `AdresseDetector` (`_titres` : le « M »
derrière SAINT, SAINTE, ST ou STE n'est plus refusé comme mot de commune) et
`NameDetector` (le « M » isolé derrière un mot Saint n'est plus le nom qui
précède le prénom connu « HERVE »). Les autres « M » restent des civilités
(« M DUPONT » : nom masqué, civilité visible).

| Mesure (`Ecluse.redact`) | Avant | Après |
|---|---:|---:|
| Balayage en capitales avec « CEDEX n » : adresses en partie en clair | 1 / 139 500 | **0** |
| fuite au caractère | 0,0 % (1 / 3 117 758) | 0,0 % (0) |
| Balayage en casse ordinaire avec « CEDEX n » (P2-178) | 8 | **7** |
| dont écriture `postale` | 1 | 0 |
| Balayage en capitales sans CEDEX | 338 | 338 (inchangé) |

Le gain en casse ordinaire est le même cas (« Saint M Hervé CEDEX 3 »), pas un
effet voulu à part. `bash bench/etat.sh` rejoué en entier sur `main` et sur la
branche : seules ces lignes diffèrent (témoin de faux titres de P2-180 et
sections de noms inclus : identiques). Non mesuré : « SAINT M HERVE » sans
CEDEX (le balayage sans CEDEX le comptait déjà parmi ses 338, cause
« autre »).
## Commune dont le nom contient un mot de voie (P2-213)

Avant : `main` au commit `bd7d24b` ; après : P2-213. Graine 42. Chemin mesuré :
**`Ecluse.redact`** (ce que reçoit le LLM). Générateur
`bench/generate_corpus_commune_voie.py`, scoreur `bench/score_commune_voie.py`.
Le balayage prend **toutes** les communes du référentiel dont la forme postale
contient un type de voie du détecteur (liste `_voies` lue dans
`adresse_detector.dart`) : 52 communes (CHAUSSEE 15, COURS 11, CHEMIN 7, RUE 7,
CLOS 3, PLACE 3, RUELLE 2, PASSAGE 2, HAMEAU 1, AVE 1). Chacune sous 72 formes :
six cases écriture × casse (quatre écritures en casse ordinaire, deux tout en
capitales), avec ou sans « CEDEX n », suivie d'une phrase, d'une ligne « code
postal + mot » (« 39314 Colis en attente ») ou d'une seconde adresse, derrière
ou non une vraie voie (« 12 chemin des Vignes », le contrôle). 3 744 documents.
Une adresse annotée en partie en clair est une fuite.

| Mesure (`Ecluse.redact`) | Avant | Après |
|---|---:|---:|
| Documents à adresse en partie en clair | **641 / 3 744** (52 communes) | **26 / 3 744** (4 communes) |
| dont code postal ou premier mot du nom en clair | **615** | **0** |
| dont fin du nom seule en clair | 26 | 26 |
| Code postal en clair | 615 | 0 |
| Seconde adresse en clair | 5 | 0 |
| Vraie voie en clair (contrôle) | 0 | 0 |
| Casse ordinaire / capitales | 426 / 2 496 ; 215 / 1 248 | 22 / 2 496 ; 4 / 1 248 |
| Avec CEDEX / sans CEDEX | 523 / 1 872 ; 118 / 1 872 | 0 / 1 872 ; 26 / 1 872 |
| Suite : phrase / « code postal + mot » / adresse | 10 ; 320 ; 311 (sur 1 248) | 10 ; 9 ; 7 |
| Derrière une vraie voie : sans / avec | 616 ; 25 (sur 1 872) | 8 ; 18 |
| Ligne « code postal + mot » masquée (en trop) | 1 246 / 1 248 | 1 248 / 1 248 |

Lecture. Le défaut visé (la voie lue à partir du mot de voie du nom, le vrai
code postal en clair) est à **0**. Le « Fini quand » de la fiche demandait 0
adresse en partie en clair sur le balayage : il en reste **26, d'une autre
cause**, identiques avant et après. Ce sont 4 communes sans CEDEX dont seule la
fin du nom reste en clair : nom de plus de quatre mots (« SAINT JEAN DE LA
RUELLE » et « SAINT CLEMENT DE LA PLACE » derrière une vraie voie ou une ligne
« code postal + mot », « VILLERS CHEMIN ET MONT LES ETRELLES ») ou lié par
« au », « et » (« Villeneuve au Chemin »). C'est la limite des communes longues
sans CEDEX (P2-205, formes A ; règle « nom exact » de P2-214 pour les
capitales), pas le mot de voie. Les 5 secondes adresses en clair du départ
venaient, dans les cas regardés, d'un nom de personne lu sur « SAINT-…-AUX-CLOS CEDEX », qui écartait
l'adresse fautive sans rien mettre à la place.

Reste du tableau de bord : identique à `main`, ligne pour ligne.

## Courriers synthétiques en capitales : fréquence de « cinq chiffres + mot neutre + CEDEX » (P2-210)

Mesure de départ, `main` au commit `8b516b7`, graine 42, **aucun `lib/`
modifié**. Chemin mesuré : **`Ecluse.redact`** (ce que reçoit le LLM).
Générateur `bench/generate_corpus_courriers.py` (400 courriers tout en
capitales, 3 185 lignes, 970 adresses annotées « code postal commune CEDEX n »),
scoreur `bench/score_courriers.py`. **Motif de construction** (écrit dans le
générateur, une hypothèse et non une observation) : un titre, une référence,
puis 5 à 9 lignes tirées à ces poids : référence 20, montant 22, quantité 18,
texte 20, adresse de retour avec CEDEX 15, et **5** pour la seule famille où un
nombre suivi d'un mot neutre et un CEDEX sont sur la même ligne
(« TOTAL 70000 EUROS HT, RETOUR A 25000 BESANCON CEDEX 2 », virgule une fois
sur deux). Chaque courrier a au moins une adresse. Un masquage en trop est de la
lisibilité perdue ; une adresse annotée en partie en clair est une fuite.

| Mesure (`Ecluse.redact`) | Résultat |
|---|---:|
| Courriers avec au moins une ligne masquée en trop | **32 / 400** (8 %) |
| Lignes masquées en trop | **35 / 3 185** |
| dont famille « nombre + mot neutre + CEDEX sur la même ligne » | **0 / 133** |
| dont famille « quantité » (« 39314 NUMEROS EN ATTENTE ») | 35 / 469 |
| Adresses annotées en partie en clair | **0 courrier** sur 400 |

Deux lectures. **Le coût de P2-201 est nul sur ce motif** : aucune des 133
lignes qui portent à la fois un nombre suivi d'un mot neutre et un CEDEX n'est
masquée en trop (le témoin pire cas de P2-200 en masque 113 / 200 parce que son
« CEDEX n » suit directement le mot neutre, sans nombre ni mot entre les
deux). Ce zéro vaut pour ce motif, pas pour du texte réel. **Le masquage en
trop mesuré ici n'a rien à voir avec CEDEX** : les 35 lignes sont toutes de la
forme « nombre à cinq chiffres + NUMEROS » ; `mots_neutres.dart` ne connaît que
« numéros » avec accent, et une écriture en capitales sans accent n'est pas
reconnue comme mot neutre (même cause possible pour « SALARIES », « RESIDENTS »,
non mesurés ici).

**Une fuite observée à la main** (tirage intermédiaire du même générateur, non
retenue dans le corpus final : 0 courrier à adresse en partie en clair sur les
400) : « A RETOURNER A : 52417 GRAFFIGNY CHEMIN CEDEX 7⏎39314 NUMEROS EN
ATTENTE » donne « 52417 GRAFFIGNY [ADRESSE_1] ». Le mot « CHEMIN » du nom de
commune est lu comme une voie et la ligne suivante comme code postal et commune ;
le code postal et « GRAFFIGNY » restent en clair. Avec « DOSSIERS » à la place de
« NUMEROS » : masqué en entier. Cas construit à la main, une commune du
référentiel public ; fréquence non mesurée.

## Mots neutres, un mot à la fois : là où la liste ne protège pas le nombre (P2-211)

Mesure de départ, `main` au commit `bd7d24b`, graine 42, **aucun `lib/`
modifié**. Chemin mesuré : **`Ecluse.redact`** (ce que reçoit le LLM).
Générateur `bench/generate_corpus_mots_neutres.py`, scoreur
`bench/score_mots_neutres.py`. Le générateur lit les mots dans
`mots_neutres.dart` lui-même (78 mots, aucune liste recopiée) et écrit 400
phrases « nombre à cinq chiffres + mot » par mot, à parts égales entre ses
cases : forme accentuée et, **quand elle diffère**, forme sans accent (cinq
mots : « à », « numéro », « numéros », « salariés », « résidents ») ; capitales
et casse ordinaire (mot en minuscules). 31 200 phrases, aucune entité annotée :
un nombre sous une détection `adresse` est un **masquage en trop** (de la
lisibilité perdue, **pas une fuite**).

**Motif de construction** (écrit dans le générateur, une hypothèse et non une
observation). Dans chaque case, les phrases tournent sur la position du nombre
(en tête, ou après « Total de », « Reste », « Lot », « Soit », « Compte de »,
« Suivi : »), sur ce qui suit le mot (rien ; une suite neutre : « en attente »,
« par an » ; un nom commun : « traites », « valides ») et, en casse ordinaire,
sur la présence d'une majuscule hors début de phrase. Tournures et suites sont
écrites sans accent, pour que seule l'écriture du mot change entre les deux
formes.

| Mesure (`Ecluse.redact`) | Nombres masqués en adresse |
|---|---:|
| Toutes les phrases | **846 / 31 200** (9 mots touchés sur 78) |
| Capitales | 639 / 15 600 |
| Casse ordinaire | 207 / 15 600 |
| Forme de la liste (accentuée ou sans accent possible) | 218 / 30 200 |
| Forme sans accent (cinq mots) | **628 / 1 000** |
| Sous un autre type que `adresse` | 0 |

Les neuf mots touchés (les 69 autres sont à 0 dans les deux casses) :

| Mot | Forme | Capitales | Casse ordinaire |
|---|---|---:|---:|
| « à » | sans accent (« A », « a ») | 83 / 100 | 38 / 100 |
| « numéro » | sans accent | 87 / 100 | 44 / 100 |
| « numéros » | sans accent | 82 / 100 | 43 / 100 |
| « résidents » | sans accent | 87 / 100 | 43 / 100 |
| « salariés » | sans accent | 82 / 100 | 39 / 100 |
| les cinq, forme accentuée | | 0 / 500 | 0 / 500 |
| « le » | de la liste | 56 / 200 | 0 / 200 |
| « la » | de la liste | 57 / 200 | 0 / 200 |
| « les » | de la liste | 54 / 200 | 0 / 200 |
| « l » | de la liste | 51 / 200 | 0 / 200 |

Trois lectures.

1. **Forme sans accent : la liste ne protège rien.** Les cinq mots accentués de
   la liste sont tous dans le même cas que « NUMEROS » (P2-210), « A » compris
   (« 70000 A TRAITER »). En capitales, 421 / 500 ; les 79 phrases épargnées
   commencent toutes par « TOTAL DE » ou « LOT » (la tournure de quantité ou de
   référence avant le nombre les protège, pas la liste) : hors de ces deux
   tournures, **421 / 421**. La forme accentuée en capitales (« NUMÉROS ») est
   à 0 / 500.
2. **Casse ordinaire : seulement en casse de phrase.** Les 207 phrases sont
   toutes de la forme sans accent et n'ont qu'une majuscule, l'initiale
   (« 39314 numeros en attente. ») : 207 / 250, les 43 épargnées étant encore
   « Total de » et « Lot ». Avec une majuscule hors début de phrase : 0 / 250.
3. **Déterminants : le coût connu de P2-187, chiffré mot par mot.** « LE »,
   « LA », « LES », « L » ne sont masqués que suivis d'un nom commun, en
   capitales : 218 / 264 (les 46 épargnées : « TOTAL DE », « LOT ») ; 0 / 536
   quand rien ou une suite neutre les suit, 0 / 800 en casse ordinaire. Ce
   n'est pas un défaut nouveau (décision du 15 novembre, P2-195 abandonnée).

Ce que ce témoin ne dit pas : une fréquence (une phrase par forme, pire cas
construit) ; le mot écrit avec une majuscule initiale en casse ordinaire
(« 39314 Numeros ») ; les mots absents de la liste.

### Après P2-212 : formes sans accent des mots neutres

`estMotNeutre` (`mots_neutres.dart`) compare aussi la forme sans accent des
cinq mots accentués de la liste (« a », « numero », « numeros », « salaries »,
« residents »), calculée depuis la même liste. Aucun de ces mots n'est premier
mot d'une commune du référentiel versionné. Même graine, même générateur,
chemin **`Ecluse.redact`** (ce que reçoit le LLM) ; masquage en trop, pas une
fuite :

| Mesure | Avant (`main`) | Après |
|---|---:|---:|
| Mots neutres, toutes les phrases | 846 / 31 200 | **218 / 31 200** |
| Forme sans accent (cinq mots) | 628 / 1 000 | **0 / 1 000** |
| Capitales / casse ordinaire | 639 et 207 / 15 600 | 218 et **0** / 15 600 |
| Mots touchés | 9 sur 78 | 4 sur 78 (« le », « la », « les », « l ») |
| Courriers (P2-210), lignes masquées en trop | 35 / 3 185 (32 courriers) | **0 / 3 185** |
| Commune suivie (P2-181), caractères de suite masqués | 5 379 / 6 659 | 5 376 / 6 659 (0 adresse en partie en clair, avant et après) |

Les 218 restantes sont le coût assumé de P2-187 (déterminants suivis d'un nom
commun, en capitales), inchangé. Le reste du tableau de bord est identique.

## SIREN masqués comme FINESS : chiffre de départ et options (P2-223)

Mesure seule, **aucun `lib/` modifié** (seule la table de types de
`bin/run_redact_bench.dart`, un outil de banc, apprend `vehicule`), `main` au
commit `0c53e59`, graine 42. Chemin mesuré : **`Ecluse.redact`** (ce que
reçoit le LLM). Le FINESS et le SIREN ont la même structure (neuf chiffres,
même clé de Luhn) : sans le mot « FINESS » à proximité, un SIREN est masqué à
confiance 0,5 (`LIMITES.md` § 1) : un identifiant d'organisation masqué en
trop, pas une fuite (l'entrepreneur individuel, dont le SIREN identifie une
personne, n'est pas traité ici). Générateur `bench/generate_corpus_siren.py`,
scoreur `bench/score_siren_finess.py`.

| Jeu | SIREN masqués comme FINESS |
|---|---:|
| Corpus v3 entier (1 000 documents) : nombres de neuf chiffres à clé valide non annotés | **42 / 42** (tous derrière « Le SIREN de la société est », à confiance 0,5) |
| Témoin de 400 documents à SIREN | **383 / 400** |
| dont avec « SIREN » juste avant, plus loin dans la phrase, ou après | 100 / 100 dans chaque cas |
| dont sans le mot SIREN (RCS, Kbis, numéro d'entreprise) | 83 / 100 |
| écriture collée / groupée 3-3-3 | 183 / 200 et 200 / 200 |

Les 17 autres du témoin ne sont pas lus comme FINESS mais masqués quand même :
sous « Extrait Kbis : immatriculation » le nombre devient une plaque
(`vehicule`) : 400 / 400 sont donc sous une détection. Aucun SIREN n'est en
clair. Vrais FINESS en clair sans option : 0 / 129 (v3) et 0 / 400 (pendant
FINESS : 400 vrais FINESS, dont ceux écrits sans le mot « FINESS » et ceux
voisins d'un SIREN).

**Options chiffrées hors `lib/`** : des filtres appliqués aux prédictions de
`Ecluse.redact`, pour compter ce qu'une règle gagnerait (SIREN en moins) et ce
qu'elle coûterait (vrais FINESS qui repartiraient **en clair**). Rien n'est
implémenté.

| Option | SIREN masqués, v3 | SIREN masqués, témoin | Vrais FINESS perdus, v3 | Vrais FINESS perdus, pendant |
|---|---:|---:|---:|---:|
| Aucune (départ) | 42 / 42 | 383 / 400 | 0 / 129 | 0 / 400 |
| « SIREN » ou « SIRET » **juste avant** le nombre | 42 / 42 | 283 / 400 | 0 | 0 |
| « SIREN » ou « SIRET » dans les 40 caractères avant | **0 / 42** | 183 / 400 | 0 | **26 / 400** |
| Idem, **seulement sans le mot « FINESS »** à proximité | **0 / 42** | 183 / 400 | 0 | **0** |
| Mot « FINESS » exigé (confiance haute seule) | 0 / 42 | **0 / 400** | **43 / 129** | **124 / 400** |
| Préfixe département valide (01 à 95, 97, 98) | 42 / 42 | 375 / 400 | 0 | 0 |
| Clé de Luhn | sans effet : 400 / 400 SIREN valides à la clé du FINESS | | | |

Lectures. (1) La fenêtre de 40 caractères réservée aux détections **sans** le
mot « FINESS » enlève les 42 SIREN du v3 et 200 du témoin sans perdre aucun
FINESS annoncé par son mot (les 26 perdus par la version sans cette réserve sont
les « SIREN S ; FINESS F »). (2) Exiger le mot « FINESS » supprime tous les
SIREN mais fait repartir en clair 43 FINESS sur 129 du v3 (ceux écrits sans le
mot) : à écarter. (3) La clé de Luhn ne sépare rien, par construction. (4) Le
préfixe ne retire que 8 SIREN sur 383 : des SIREN **tirés au hasard** ici (les
premiers chiffres d'un vrai SIREN ne sont pas uniformes, non mesuré faute de
donnée réelle). (5) Les 183 restants du témoin sont les SIREN **sans** mot
SIREN avant le nombre (« SIREN de l'entreprise gestionnaire » après lui, RCS,
Kbis) : aucune option de cette liste ne les atteint.

Ce que cette mesure ne dit pas : une fréquence réelle de SIREN dans des textes
de santé (documents construits, un nombre par document) ; le coût d'une option
sur un FINESS dont le texte voisin contient « SIREN » dans un autre sens ; les
SIRET (14 chiffres : le détecteur ne lit pas neuf chiffres dans un SIRET).


## SIREN nommé : type `siren` (P2-248)

Changement de `lib/` (`FinessDetector`, `EntityType.siren`, jeton `[SIREN_n]`),
rejeu complet de `bench/etat.sh` sur la branche, graine 42. Chemins mesurés,
ligne par ligne : les SIREN typés et le témoin de 400 documents viennent de
**`Ecluse.redact`** (ce que reçoit le LLM) ; la précision FINESS vient du
**moteur seul** (`ecluse_core`, `run_ecluse.dart`), sur le corpus « structurel »
recoupé à la largeur 60 et à la largeur 90 (section « mise en page », P2-153) :
ce n'est **pas** une mesure de ce que reçoit le LLM. La section P2-223 ci-dessus
décrit l'état d'**avant** P2-248.

Formulation de la seconde copie de la section (conservée, P2-257) :

Changement de `lib/` (`FinessDetector`, `EntityType.siren`, jeton `[SIREN_n]`),
rejeu complet de `bench/etat.sh` sur la branche, graine 42. Chemin mesuré :
**`Ecluse.redact`** (ce que reçoit le LLM) pour les corpus de la section
précédente ; le tableau « Ecluse finess » du benchmark d'identifiants
(`bench/score.py`) vient de `run_ecluse.dart` et de `Ecluse.redact` selon la
ligne (les deux lignes du tableau changent de la même façon). La section
P2-223 ci-dessus décrit l'état d'**avant** P2-248.

| Mesure | Avant | Après |
|---|---:|---:|
| Corpus v3, `Ecluse.redact` : SIREN typés `finess` / `siren` | 42 / 0 | 0 / 42 |
| Précision FINESS, moteur seul, corpus structurel largeur 60 et 90 (rappel inchangé 100 %) | 75,4 % (42 faux positifs) | 100,0 % (0) |
| Témoin de 400 documents à SIREN lus comme FINESS | 383 | 83 |
| dont SIREN annoncé par le mot (« SIREN » avant, après, dans la phrase) | 300 / 300 | 0 / 300 |
| SIREN sans le mot (RCS, Kbis, numéro d'entreprise), toujours lus FINESS | 83 | 83 |

Le reste du tableau de bord est identique octet pour octet (hors lignes de
temps et du commit) : même couverture au caractère sur tous les corpus, aucune
entité de moins masquée. Les 83 SIREN sans le mot restent à confiance 0,5
sous le type `finess` (voir `LIMITES.md` § 1).

## Patronyme seul hors civilité : chiffre de départ (P2-218)

Mesure seule, **aucun `lib/` modifié**, `main` au commit `0c53e59`, graine 42.
Chemin mesuré : **`Ecluse.redact`** (ce que reçoit le LLM), appelé soit
document par document, soit avec une session de dossier (`--dossier`). Corpus
de dossiers réaliste entier (397 documents), scoreur
`bench/score_patronyme_seul.py` : un nom est « manqué hors civilité » quand un
caractère non blanc d'un de ses mots, civilité exclue, n'est sous aucune
détection. Un nom manqué part en clair dans le texte que reçoit le LLM (pas de
filet derrière `Ecluse.redact` ici).

| Noms annotés | Mentions | Manquées, document par document | Manquées, en session |
|---|---:|---:|---:|
| Patronyme seul (un mot) | 116 | **112** | **0** |
| Plusieurs mots (civilité, prénom, ou les deux avec le nom) | 476 | 0 | 0 |

Patronyme seul, par tournure (celle qui précède ou suit le nom, lue par
expression régulière) :

| Tournure | Mentions | Manquées, document par document | En session |
|---|---:|---:|---:|
| « le dossier de X » / « au dossier de X » | 49 | 48 | 0 |
| « entretien avec X » | 26 | 24 | 0 |
| « X a confirmé… » | 22 | 22 | 0 |
| « à la demande de X » | 19 | 18 | 0 |
| autre | 0 | 0 | 0 |

Ce que montrent ces chiffres : hors session, le patronyme seul n'est quasi
jamais masqué (112 / 116 ; les 4 masqués portent un patronyme qui est aussi un
prénom du référentiel, « Gauthier », détecté pour cette raison et non par la
tournure), quelle que soit la tournure ; en session, 0 manqué. La sonde non versionnée du 17 novembre (16 sur 83 sur 54 documents) est
cohérente : 16 / 54 ≈ 112 / 397 par document.

**Témoin** (`bench/generate_corpus_tournures_sans_nom.py`, 400 documents,
aucune personne, aucune entité annotée) : les cinq tournures ci-dessus
(« adressé à X » en plus, du corpus P2-14) remplies par un nom commun en
minuscules (« le dossier de presse »), un mot commun à majuscule (« Succès a
confirmé »), un nom de commune (« à la demande de Paris ») ou un organisme
(« la Mairie »), 20 documents par case. Chaque masquage y serait un masquage en
trop (lisibilité perdue), pas une fuite.

| Témoin (`Ecluse.redact`) | Masqués à tort |
|---|---:|
| Toutes cases | **0 / 400** |
| Par tournure (5 × 80) | 0 dans chacune |
| Par genre (4 × 100) | 0 dans chacun |

Un correctif qui masquerait le mot qui suit ces tournures (tâche suivante
possible, P2-220) a donc un budget de départ : 112 noms à rattraper, 0 masquage
en trop à ne pas dépasser. Ce que ce témoin ne dit pas : une fréquence réelle
(phrases construites sur les mêmes gabarits que le corpus, une phrase par
document), les noms de personnes qui sont aussi des mots (« Marchand »,
« Petit » : P2-221), les tournures hors de ces cinq.

## Patronyme seul derrière une tournure de personne : seuils non tenus ensemble (P2-220)

`main` au commit `e48ba49` pour l'état d'avant, graine 42, rejeu complet de
`bench/etat.sh` des deux côtés. Chemin mesuré : **`Ecluse.redact`** (ce que
reçoit le LLM), appelé document par document, sans dossier. Règle : un mot à
majuscule initiale derrière « dossier de », « à la demande de », « entretien
avec » (un ou deux mots) ou devant « a confirmé » (un mot) est un nom, sauf mot
neutre, statut, sigle, mot d'établissement, pronom ou commune de 10 000
habitants et plus (`communes_grandes.dart`) ; le mot qui suit une tournure doit
commencer par une majuscule, et le sujet de « a confirmé » ne doit être précédé
ni d'un article capitalisé ni d'un autre mot capitalisé.

| Mesure | Avant | Après | Seuil de la fiche |
|---|---:|---:|---|
| Noms annotés manqués, patronyme seul (corpus de dossiers réaliste, 116 mentions) | **112** | **4** | au plus 28 : tenu |
| Témoin de P2-218 : phrases sans nom masquées à tort (400 phrases) | **0** | **80** (20 %) | au plus 4 (1 %) : **non tenu** |

Les 4 mentions encore manquées sont le même patronyme (« Gaillard ») dans les
quatre tournures : c'est aussi une commune de plus de 10 000 habitants, donc
écartée par la table. Les 80 masquages à tort sont tous des noms communs écrits
avec une majuscule derrière la tournure (genre `commun_majuscule`, 80 sur 100) ;
les genres `lieu`, `organisme` et `commun_minuscule` donnent 0 sur 100 (2
organismes, « L'Inspection a confirmé », ont été corrigés en cours de tâche).
Sans la table des communes, les 100 phrases `lieu` seraient masquées aussi. Par
tournure : 20 sur 80 pour chacune des quatre tournures retenues, 0 sur 80 pour
« adressé à » (non retenue : aucune mention dans le corpus de dossiers).

Ce qui change ailleurs dans le tableau de bord (rejeu complet, tout le reste
identique) : corpus flou adversarial, nom : précision 72,5 → 73,2 %, rappel
68,4 → 71,4 %, fuite au caractère 13,9 → **11,0 %**, global 6,7 → **5,3 %**
(identique aux largeurs 60 et 90) ; dossiers adversarial, jetons 445 → 455 et
596 → 606 (collisions et fausses fusions : 7 et 7, inchangées) ; à casse mixte,
noms non détectés 12 → 8. Une dégradation : restaurations non identiques du
corpus flou adversarial, 61 → **62** (document 59 : deux personnes de même
patronyme, « Reynaud », dont une est désormais détectée en entier ; avant, les
deux étaient en clair ; c'est la limite de `LIMITES.md` § 5.3, pas une nouvelle
fuite).

Ce que ces chiffres ne disent pas : une fréquence réelle (corpus synthétiques,
gabarits des générateurs) ; la fréquence d'un nom commun capitalisé derrière ces
tournures dans de vrais textes (rare en prose, courante dans des titres et des
intitulés de dossier) ; les noms de famille qui sont aussi des mots (« Marchand »,
« Petit » : P2-221).

## Tournures de personne : témoin élargi, chiffres de départ (P2-226)

Mesure seule, **aucun `lib/` modifié**, `main` au commit `6dcf041`, graine 42
(elle ne sert qu'à mélanger l'ordre des documents). Chemin mesuré :
**`Ecluse.redact`** (ce que reçoit le LLM), un appel par document, sans
dossier. Générateur `bench/generate_corpus_tournures_personne.py`, scoreur
`bench/score_tournures_personne.py`. Mêmes quatre tournures que P2-220 et mêmes
gabarits que le témoin de P2-218 ; cinq familles de 24 mots, chaque mot une fois
dans chaque tournure (96 phrases par famille, 480 en tout), aucun des douze noms
communs de P2-218 repris. Un mot de famille sans personne est « masqué à tort »
dès qu'un de ses caractères est sous une détection ; un patronyme est
« masqué » seulement s'il est couvert en entier, sinon c'est une **fuite**.

| Famille | Contenu | Masqués | Par tournure (dossier de / à la demande de / entretien avec / a confirmé) |
|---|---|---:|---|
| `roles` | civilités seules, parenté, fonctions soignantes et sociales | **96 / 96 à tort** | 24 / 24 / 24 / 24 |
| `organismes` | organismes publics ou associatifs, marques, un ou deux mots | **83 / 96 à tort** | 22 / 22 / 22 / 17 |
| `communs` | noms communs à majuscule | **96 / 96 à tort** | 24 / 24 / 24 / 24 |
| `patronymes_communes` | patronymes qui sont aussi une commune de 10 000 habitants et plus | **0 / 96 (96 fuites)** | 0 / 0 / 0 / 0 |
| `patronymes_noms_communs` | patronymes qui sont aussi un nom commun | 96 / 96 (0 fuite) | 24 / 24 / 24 / 24 |

Toutes les détections sont de type `nom`, et toutes portent sur le mot de la
tournure (0 détection ailleurs dans les phrases).

Lectures. (1) Les familles `roles` et `communs` sont masquées en entier :
P2-220 lit tout mot à majuscule derrière la tournure comme un nom, et ni les
civilités seules (« entretien avec Madame »), ni la parenté, ni les fonctions,
ni les noms communs hors `mots_neutres.dart` ne sont exclus. C'est le même
défaut que les 80 phrases `commun_majuscule` du témoin de P2-218, sur des mots
que ce témoin ne contenait pas. (2) Les 13 organismes en clair ont trois
causes : un sigle déjà exclu (« MDPH », 4 phrases) ; une marque qui est aussi
une commune de la table (4 phrases) ; et devant « a confirmé », un nom de deux
mots, dont le second est soit précédé d'un mot capitalisé (règle de P2-220),
soit en minuscules (5 phrases). Pour un organisme de deux mots derrière les
trois autres tournures, seul un des deux mots est parfois masqué : il compte
quand même comme masqué à tort. (3) Les 96 patronymes-communes restent
**tous en clair** : la table `communes_grandes.dart` qui protège les phrases
`lieu` du témoin de P2-218 les écarte aussi (P2-228). (4) Les patronymes qui
sont aussi un nom commun sont tous masqués, au prix du point (1) : la règle ne
les distingue pas d'un nom commun.

Ce que ces chiffres ne disent pas : une fréquence réelle (pires cas construits,
un mot par phrase, gabarits fixes) ; les mêmes mots en minuscules ou en tête de
phrase hors tournure ; le corpus de dossiers (inchangé : 4 patronymes seuls
manqués sur 116, section de P2-218).

## Tournures de personne : grandes communes écartées après « à la demande de » seulement (P2-228)

`main` au commit `79b2044` pour l'état d'avant, graine 42, rejeu complet de
`bench/etat.sh` des deux côtés, comparé ligne à ligne. Chemin mesuré :
**`Ecluse.redact`** (ce que reçoit le LLM), document par document, sans
dossier. Règle changée dans `NameDetector` : une commune de 10 000 habitants et
plus (`communes_grandes.dart`) n'est plus écartée derrière « le dossier de »,
« l'entretien avec » et devant « a confirmé » ; elle l'est toujours après « à
la demande de ». Fait avant P2-227, sur décision du mainteneur du 19 novembre :
les fuites passent avant le sur-masquage.

| Mesure | Avant | Après |
|---|---:|---:|
| Témoin P2-226, `patronymes_communes` : masqués (fuites) | 0 / 96 (96) | **72 / 96 (24)** |
| dont « dossier de », « entretien avec », « a confirmé » | 0 / 72 | **72 / 72** |
| dont « à la demande de » (exclusion gardée) | 0 / 24 | 0 / 24 |
| Corpus de dossiers réaliste : patronymes seuls manqués | 4 / 116 | **1 / 116** |
| Témoin P2-218 : phrases sans nom masquées à tort | 80 / 400 | **140 / 400** |
| dont genre `lieu` | 0 / 100 | **60 / 100** |
| Témoin P2-226, `organismes` masqués à tort | 83 / 96 | 86 / 96 |

Coût, cas par cas. (1) Les 60 phrases `lieu` du témoin de P2-218 : ce sont
**toutes** les phrases de ce genre derrière les trois tournures concernées (20
par tournure, douze grandes villes) ; derrière « à la demande de », 0 sur 20 ;
« adressé à » n'est pas une tournure de P2-220. Une ville désignée ainsi
(« le dossier de Besançon », « Paris a confirmé ») est désormais masquée comme
un nom : de la lisibilité perdue, pas une fuite. (2) Les 3 organismes de plus
sont la même marque, aussi nom de commune (« Orange »), derrière les trois
tournures. (3) Le patronyme encore manqué du corpus de dossiers est « Gaillard »
après « à la demande de » : la fuite connue qui reste (24 sur 24 au témoin de
P2-226 pour cette tournure).

Tout le reste du tableau de bord est identique, en particulier les corpus
flous (réaliste, adversarial, témoins, variantes de casse) et les corpus de
dossiers.

## Tournures de personne : mots de rôle et de parenté en clair (P2-227)

`main` au commit `79b2044` pour l'état d'avant (tableau de bord de P2-228),
graine 42, rejeu complet de `bench/etat.sh` des deux côtés, comparé ligne à
ligne. Chemin mesuré : **`Ecluse.redact`** (ce que reçoit le LLM), document par
document, sans dossier. Règle changée dans `NameDetector` : un mot de rôle ou de
parenté (liste fermée écrite d'après la langue, plus les terminaisons de métier
« -thérapeute », « -logue », « -iatre », « -phoniste », « -pédiste ») derrière
une tournure de personne n'est plus lu comme un patronyme ; s'il est suivi d'un
nom, seul le nom est candidat.

| Mesure | Avant | Après |
|---|---:|---:|
| Témoin P2-226, `roles` masqués à tort | 96 / 96 | **0 / 96** |
| dont par tournure (dossier de / à la demande de / entretien avec / a confirmé) | 24 / 24 / 24 / 24 | 0 / 0 / 0 / 0 |
| Témoin P2-226, total des masquages à tort (type `nom`) | 278 | 182 |
| Témoin P2-226, `patronymes_communes` et `patronymes_noms_communs` | inchangés | inchangés |
| Corpus de dossiers réaliste : patronymes seuls manqués | 1 / 116 | 1 / 116 |

Tout le reste du tableau de bord est identique (diff ligne à ligne : seules
changent la ligne du commit, les cinq lignes `roles` et le total des
masquages à tort).

Généralisation, dite sans détour. Sur les 24 mots du témoin, 22 sont dans la
liste ; « Psychologue » et « Ergothérapeute » n'y sont pas mais sont reconnus
par les terminaisons. **Aucun mot du témoin n'échappe à la fois à la liste et
aux terminaisons** : le témoin ne mesure donc pas ce qui se passe pour un rôle
hors des deux (« Aidant », « Veuve », « Concierge » : masqués, comme avant).
Les cas de `tournure_mots_de_role_test.dart` ajoutent des formes que le témoin
ne contient pas (« Famille », « Maman », « Kiné », « Orthophoniste »,
« Psychiatre », « Soeur », « MERE »), qui sont une vérification, pas une
fréquence.

Ce que ces chiffres ne disent pas : une fréquence réelle (pires cas construits) ;
un patronyme identique à un mot de la liste (« Maître », « Cadre », « Chef »,
« Mari » existent comme noms de famille) n'est plus rattrapé par la tournure
seule : fuite possible, non mesurée, que le témoin de P2-226 ne contient pas.
## Tournures de personne : organismes en clair (P2-229)

État d'avant : `main` avec P2-227 fusionnée (commit `3c35cba`) ; les premières
mesures ont été prises sur `a761fb3` (86 → 43, identiques : les deux familles
sont indépendantes), puis rejouées après fusion. Graine 42, rejeu complet de `bench/etat.sh` des deux côtés, comparé ligne à ligne. Chemin
mesuré : **`Ecluse.redact`** (ce que reçoit le LLM), document par document, sans
dossier. Règle changée dans `NameDetector` : un organisme de la liste fermée
(organismes nationaux et services publics ou associatifs du soin et du social,
écrite d'après le secteur, plus des sigles en capitales : CAF, CPAM, URSSAF,
MSA…) qui couvre le mot candidat n'est plus lu comme un patronyme ; suivi d'un
nom (« Emmaüs Quenelle »), le nom reste masqué. **Les marques commerciales ne
sont pas dans la liste.**

| Mesure | Avant | Après |
|---|---:|---:|
| Témoin P2-226, `organismes` masqués à tort | 86 / 96 | **43 / 96** |
| dont « dossier de » / « à la demande de » / « entretien avec » / « a confirmé » | 23 / 22 / 23 / 18 | 11 / 10 / 11 / 11 |
| Témoin P2-226, total des masquages à tort (`nom`) | 182 | 139 |
| Familles de patronymes de P2-226, témoin de P2-218, corpus de dossiers | inchangés | inchangés |

Tout le reste du tableau de bord est identique (diff ligne à ligne : la ligne
du commit, les cinq lignes `organismes`, le total).

**« Fini quand » non atteint** : la fiche demandait la famille divisée par
quatre au moins (≤ 21 sur 96) ; elle est divisée par deux. Les 43 restants
sont les 11 marques commerciales du témoin (Doctolib, SNCF, EDF, Engie, Orange,
Bouygues, Leboncoin, Amazon, Google, Microsoft, Decathlon) devant les quatre
tournures : 44 phrases, dont une déjà en clair (43 masquées). Une marque n'est pas un
organisme national ou associatif du soin et du social, et plusieurs sont aussi
un nom de commune (« Orange ») ou de famille : les ajouter à la liste sort de
la fiche. Décision du mainteneur : (a) les laisser masquées (dans le doute) ;
(b) une liste de marques courantes, avec le risque de fuite pour celles qui
sont aussi des patronymes.

Généralisation. Sur les 12 organismes non-marques du témoin, 8 sont dans la
liste par leur nom (France Travail, Assurance Maladie, Sécurité sociale,
Croix-Rouge, Emmaüs, Secours populaire, Mutualité française, Ameli) et 4 par
les sigles (CAF, CPAM, URSSAF, MSA) ; MDPH l'était déjà (P2-211). **Aucun mot
non-marque du témoin n'est hors liste** : la généralisation à un organisme
absent de la liste n'est donc pas mesurée (elle reste masquée). Les cas de
`tournure_organismes_test.dart` ajoutent des formes que le témoin ne contient
pas (« Pôle emploi », « Secours catholique », « Restos du Cœur », « Banque
alimentaire », « Protection judiciaire de la jeunesse »).

Ce que ces chiffres ne disent pas : une fréquence réelle (pires cas
construits) ; un organisme de deux mots suivi d'un nom (« France Travail
Brisemotte ») garde le comportement d'avant (le nom, au-delà de deux mots,
n'est pas lu).

## Tournures de personne : que faire des grandes communes après « à la demande de » (P2-233)

Mesure seule, aucune correction. `main` au commit `63e4d68`, graine 42. Chemin
mesuré : **`Ecluse.redact`** (ce que reçoit le LLM), document par document, sans
dossier (`run_redact_bench.dart`, `run_dossiers_bench.dart`), puis les scores
du tableau de bord (`score_tournures_personne.py`, `score_tournures_sans_nom.py`,
`score_patronyme_seul.py`). Les variantes ont été jouées sur une **copie
jetable** de `NameDetector` (liste de communes écartées lue d'une variable
d'environnement, jamais commitée) : aucun fichier de `lib/` n'est modifié par
cette PR. Seule la règle d'exclusion change entre variantes : une commune de
la liste est écartée **derrière « à la demande de » seulement** (P2-228) ; les
trois autres tournures n'écartent déjà aucune commune.

**Contrôle de la méthode** : la variante « seuil 10 000 » relue depuis
`geo_communes.csv.gz` (colonne `PMUN`, communes sans population retenues, comme
`tools/build_communes_grandes.py`) donne exactement les chiffres de `main`
(24 fuites sur 96, 60 lieux masqués sur 100, 1 manqué sur 19) : elle reproduit
la liste écrite en dur.

Témoins : P2-226 (famille `patronymes_communes`, 24 mots × 4 tournures,
fuite = patronyme resté en clair), P2-218 « tournures sans nom » (100 phrases
`lieu`, un lieu masqué est un masquage en trop), corpus de dossiers réaliste
(116 patronymes seuls, dont 19 derrière « à la demande de »).

| Option | Fuites, « à la demande de » (sur 24) | Fuites, 4 tournures (sur 96) | Lieux masqués à tort, « à la demande de » (sur 20) | Lieux masqués à tort, total (sur 100) | Dossiers, « à la demande de » manqués (sur 19) |
|---|---:|---:|---:|---:|---:|
| A. `main` : communes de 10 000 habitants et plus | 24 | 24 | 0 | 60 | 1 |
| B. seuil 30 000 | 13 | 13 | 0 | 60 | 0 |
| C. seuil 50 000 | 4 | 4 | 0 | 60 | 0 |
| D. seuil 100 000 (39 communes + 20 sans population dans le fichier) | 0 | 0 | 1 | 61 | 0 |
| E. seulement Paris, Lyon, Marseille et Mayotte (sans population) | 0 | 0 | 16 | 76 | 0 |
| F. ne plus rien écarter | 0 | 0 | 20 | 80 | 0 |

(Les 60 lieux de la ligne A viennent des trois autres tournures, inchangés
dans toutes les variantes ; la fuite des trois autres tournures est déjà nulle
depuis P2-228.)

Pourquoi le seuil sépare ici : les 24 patronymes-communes du témoin ont entre
11 423 (Gaillard) et 67 571 habitants (Calais) ; les 10 communes des phrases
`lieu` de « à la demande de » en ont entre 89 916 (Poitiers) et plus de
500 000 (Toulouse), Paris et Lyon n'ayant pas de population dans le fichier.
Aucun seuil entre environ 68 000 et 89 000 ne coûte quoi que ce soit sur ces
deux témoins, mais **ce n'est pas une raison de le choisir** : ce serait régler
la règle sur le témoin.

**Ce que la mesure ne dit pas.**
- Le témoin `lieu` ne contient que de grandes villes (10 communes, toutes
  au-dessus de 89 000 habitants). Le coût réel d'un seuil de 30 000 à 100 000
  sur « à la demande de Dole » ou « à la demande de Vesoul » (communes de
  10 000 à 100 000 habitants employées comme lieu) n'est **pas mesuré** : une
  telle phrase serait masquée en trop, pas fuitée. La France compte 751
  communes de 10 000 à 30 000 habitants, 154 de 30 000 à 50 000, 91 de 50 000 à
  100 000, 39 de plus de 100 000 et 20 sans population dans le fichier.
- L'option « indice voisin de lieu ou de personne dans la phrase » n'est **pas
  mesurable sur ces témoins** : les phrases `lieu` et `patronymes_communes` de
  « à la demande de » ont le même gabarit (« Rendez-vous reporté à la demande de
  X ; une nouvelle date sera proposée »). Aucun indice voisin ne les sépare ; en
  chiffrer un reviendrait à inventer des phrases. Il faudrait d'abord un témoin
  à gabarits variés.
- L'option « chefs-lieux seulement » n'est **pas mesurable** : le dépôt n'a pas
  de référentiel des chefs-lieux (`geo_communes.csv.gz` n'a que `COM`, `DEP`,
  `REG`, `PMUN`, `NORM`, `LIBELLE`) ; en ajouter un est une nouvelle donnée à
  documenter dans `DATA_SOURCES.md`.
- Le témoin des dossiers n'a que 19 patronymes derrière « à la demande de » et
  1 manqué à l'état actuel (non identifié nommément ; c'est une commune de 10 000 à 30 000
  habitants, puisqu'il disparaît dès le seuil à 30 000) ; corpus synthétique.
- Aucune mesure sur des textes réels : la fréquence réelle de « à la demande de
  <commune> » face à « à la demande de <patronyme-commune> » n'est pas connue.

**Recommandation** (au mainteneur de trancher) : l'option **D, seuil à
100 000 habitants**. Elle supprime les 24 fuites du témoin (24 → 0) pour un lieu
masqué en trop sur 100 (Poitiers), suit la règle « dans le doute on masque »
(une fuite d'un patronyme coûte plus qu'un lieu masqué) et se justifie sans
regarder le témoin (seuil rond, 39 communes). Les options B et C laissent des
fuites (13 et 4) ; E et F masquent 16 et 20 des 20 lieux de la tournure, soit
le défaut même que P2-228 corrigeait pour « à la demande de Paris ».
Tâche de code à ouvrir ensuite : changer `SEUIL` de
`tools/build_communes_grandes.py` (10 000 → 100 000) pour la seule liste de
« à la demande de » **après** avoir élargi le témoin `lieu` à des communes de
10 000 à 100 000 habitants, pour chiffrer le coût réel ; si ce coût est
jugé trop haut, F est la variante sûre (aucune fuite, tous les lieux masqués).
## Noms « prénom + verbe » : « Sophie rappelle. » proposé en entier (P2-235)

Mesure seule, aucune correction, aucun fichier de `lib/` modifié. `main` au commit
`63e4d68`, graine 42, chemin **`Ecluse.redact`** (entités rendues, document par
document, sans dossier sauf indication), script jetable hors dépôt qui n'imprime
que des comptes.

**Règle citée.** `NomMinusculesDetector` (`nom_minuscules_detector.dart`, branche
« un **prénom connu** suivi d'un mot → confiance 0.5 », annoncée dans le
commentaire de classe, point 2, et dans `LIMITES.md` § 5 « Texte sans
majuscules », P2-119 et P2-124). Elle ne s'active que pour un texte sans
majuscule hors début de phrase (casse de phrase, minuscules : `casse.dart`,
P2-138), donc pour un message court comme « Sophie rappelle. » ; `NameDetector`
ne propose que « Sophie » (0 à 6, confiance 0,5), et `resolveOverlaps` garde la
plus longue (0 à 15). Le mot qui suit est écarté seulement s'il est un mot outil
(`_motsOutils`) ou un qualificatif (adjectif, participe) : un verbe conjugué n'est
dans aucune des deux listes.

**Comptes sur les corpus existants** (80 fichiers de `bench/`, 53 167 documents
lus dont les variantes de casse d'un même corpus, 20 641 entités `nom` rendues) :
- **0** entité de confiance 0,5 (règle « prénom + mot ») qui déborde d'un nom
  annoté : les corpus n'exercent pas le cas « prénom + verbe » ;
- 164 entités `nom` débordent d'un nom annoté sur un mot en minuscules, **d'une
  autre branche** du même détecteur (civilité + prénom + patronyme : jusqu'à
  « deux mots » après le prénom, confiance 0,7) ; le mot est toujours « présente »
  (« monsieur marc loyer présente une grille… ») : 65 dans le flou adversarial en
  minuscules, 65 en casse de phrase, 34 en mixte ; 0 dans le réaliste, le témoin,
  les dossiers, les QI et les transcrits. Les autres débordements (1 349) sont des
  mots en capitales dans les corpus en MAJUSCULES et en mixte : sans casse, un
  verbe ne se distingue pas d'un nom, non classé ici.

**Sonde de la règle** (400 phrases « Prénom verbe. » : 10 prénoms courants × 40
verbes conjugués courants, texte d'une phrase) : **340 sur 400** (85 %) donnent un
nom de deux mots (le verbe est masqué avec le prénom), 60 le prénom seul, aucune ne
donne rien. Les six verbes jamais pris sont ceux que les listes écartent déjà
(arrive, vient, veut, doit, peut, entre). Phrases fabriquées pour la sonde : elles
disent ce que fait la règle, **pas la fréquence** dans de vrais textes.

**Effet en chaîne, non annoncé dans `LIMITES.md`** : `patronymeEtabli` (couple de
deux mots à 0,5 dont un seul est un prénom) retient le verbe comme patronyme
établi. Sondé : « Sophie rappelle. Elle rappelle demain et il rappelle lundi. » →
les trois « rappelle » sont masqués en `[NOM_1]` ; dans un dossier, « Le médecin
rappelle lundi. » du document suivant l'est aussi (`[NOM_2]`). Le défaut ne fait
pas fuiter une donnée (tout ce qui est masqué en trop l'est), il retire du sens au
texte envoyé : un verbe devient un nom dans toute la suite d'un dossier.

**Verdict.** Le débordement d'un prénom sur le mot suivant est **voulu** quand
ce mot peut être le patronyme (sans casse, rien ne le distingue : « marc loyer »),
et le commentaire de classe l'assume pour les adjectifs. Sur un **verbe** conjugué,
c'est un **défaut non décidé** : ni le commentaire, ni `DECISIONS.md`, ni
`LIMITES.md` ne parlent du verbe, et l'établissement du verbe comme patronyme en
dossier n'est écrit nulle part. Sur-masquage seulement, pas de fuite ; fréquence
réelle inconnue (aucun corpus ne contient « prénom + verbe », et aucun texte réel
n'a été lu). La branche civilité a le même défaut avec « présente » (164
occurrences des corpus adversariaux).

Tâche de code à ouvrir si le mainteneur le juge utile : écarter les formes
verbales courantes du mot qui suit un prénom (liste fermée de verbes d'usage,
`_qualificatif` étendu), puis ne pas établir de patronyme à partir d'un mot de
cette liste ; **test d'abord** (« Sophie rappelle. » → « Sophie » seul ; « marc
loyer présente » → « marc loyer »), témoin de faux amis et corpus en minuscules
inchangés, fuite des noms du flou adversarial en minuscules (27 %) non dégradée.
## Tournures de personne : les 43 « organismes » restants sont tous des marques (P2-234, bloquée)

Classement des causes demandé par la fiche, sur `main` (commit `63e4d68`), graine 42,
chemin **`Ecluse.redact`** document par document, témoin P2-226, famille
`organismes`. **Aucune correction** : la tâche est bloquée (voir plus bas).

| Cause prévue par la fiche | Phrases masquées à tort |
|---|---:|
| mot absent de la liste de P2-229 | 0 |
| organisme de deux mots dont un seul mot est reconnu | 0 |
| marque ou entreprise commerciale | **43 / 43** |

Les 43 phrases masquées portent 11 mots, chacun devant les quatre tournures
(Orange : 3 sur 4, une déjà en clair) : EDF, SNCF, Engie, Bouygues, Orange,
Google, Amazon, Microsoft, Leboncoin, Decathlon, Doctolib. Aucun organisme de la
liste de P2-229 n'est masqué à tort : le « Fini quand » de la fiche (famille
divisée par deux, soit 21 au plus) ne peut donc pas passer par une règle de
détecteur, et les causes « liste incomplète » et « deux mots » ne se présentent
pas sur ce témoin.

Pourquoi aucune règle n'est livrable sans décision :
- **Sigle en capitales** (EDF, SNCF, 8 phrases sur 43) : indiscernable par la forme
  d'un patronyme écrit en capitales, convention courante des courriers
  administratifs. Sondé sur `main` : « Le dossier de DUPONT est transmis. »,
  « Le dossier de MARTIN a été clos. » et « Le dossier de SNCF est transmis. »
  donnent le même masquage ; une règle « mot tout en capitales de 2 à 5 lettres
  n'est pas un nom » ferait fuiter le patronyme. Le corpus de dossiers ne peut pas
  chiffrer ce risque : ses noms annotés derrière une tournure ne sont jamais en
  capitales dans les textes à casse ordinaire (0 sur 116 mots seuls au corpus
  réaliste, 0 sur 70 à l'adversarial).
- **Mots de marque** (Google, Amazon, Orange, Engie…) : seule une liste, que la
  décision de P2-229 laisse au mainteneur (« dans le doute on masque » ou liste
  de marques avec risque de fuite pour celles qui sont aussi des patronymes ou des
  communes : Orange). La fiche interdit l'ajout mot à mot.

Décision attendue (reprend celle de P2-229) : (a) laisser ces marques masquées,
clore P2-234 sans code ; (b) une liste de marques courantes, avec le risque de
fuite pour celles qui sont aussi des patronymes ; (c) des tournures qui les
écartent par le contexte (non mesurable sur ce témoin : même gabarit de phrase).

## Mise en page : textes recoupés aux espaces (P2-153)

Les corpus flous (graine 42) et structurel (v3, 1 000 documents) recoupés par
`bench/generate_corpus_mise_en_page.py` : chaque espace ordinaire devient un
retour à la ligne quand le mot suivant dépasserait la largeur (60 puis 90
caractères), rien d'autre ne change, longueur et offsets conservés
(vérifié par `test_mise_en_page.py`). **Aucun détecteur modifié** : la règle
« un span ne traverse jamais un saut de ligne » (`LIMITES.md` § 5.2) est
assumée, ceci la chiffre.

Entités floues, fuite au caractère (part des caractères annotés restés en
clair), documents refusés exclus du calcul :

| Corpus | Retours ajoutés | nom | adresse | établissement | **global** | Refus¹ |
|---|---:|---:|---:|---:|---:|---:|
| réaliste, sans recoupe | 0 | 27,7 % | 0 % | 0 % | **7,5 %** | 0 |
| réaliste, largeur 90 | 84 | 27,7 % | 0 % | **0 %** (9,2 % avant P2-173) | **7,5 %** (9,3 %) | 0 |
| réaliste, largeur 60 | 256 | 27,6 % | **0 %** (1,3 % avant P2-173) | **0 %** (0,5 %) | **8,2 %** (8,6 %) | 3 (2 avant P2-173) |
| adversarial, 60 et 90 | 7 et 0 | **11,0 %** (13,9 % avant P2-220) | 0 % | 0 % | **5,3 %** (6,7 %) | 0 |
| témoin, 60 et 90 | 292 et 12 | | | | **0 prédiction** | 0 |

Entités **coupées par une fin de ligne** (P2-173, `bench/entites_coupees.py`),
chemin **`Ecluse.redact`** (ce que reçoit le LLM), documents refusés exclus.
« Couverte » = tous ses caractères hors blancs sont sous une détection, quel
qu'en soit le type :

| Corpus | Type | Coupées | Couvertes avant P2-173 | Couvertes après |
|---|---|---:|---:|---:|
| réaliste, largeur 90 | établissement | 44 | 0 (37 entièrement en clair, 7 en partie ; 503 caractères) | **44** |
| réaliste, largeur 90 | adresse | 83 | 83 | 83 |
| réaliste, largeur 60 | établissement | 4 | 0 (4 en partie ; 24 caractères) | **4** |
| réaliste, largeur 60 | adresse | 96 avant, 95 après² | 83 (13 en partie : dernier mot de la commune ; 65 caractères) | **95** |
| adversarial, 60 et 90 | adresse | 106 | 106 | 106 |

² Une des 13 adresses est dans le document refusé en plus après P2-173
(note ¹) : 12 sont maintenant couvertes, 1 n'est plus envoyée.

La fin de ligne est neutralisée dans la vue de détection quand le nom
continue visiblement (mot de liaison en fin ou en début de ligne, nom propre
qui n'ouvre pas une phrase, mot-clé de plusieurs mots coupé) ; règles et
restes dans `LIMITES.md` § 5.2. Témoins recoupés : toujours 0 prédiction.
Prose de 78 fichiers `.md` du dépôt (13 791 fins de ligne), mesure faite à la
main le 13 novembre, hors tableau de bord : détections identiques avant et
après.

Corpus structurel (rappel ; sans recoupe : 100 % partout). Deux chemins,
à ne pas confondre :

| Largeur | Chemin | NIR | RPPS | IBAN | FINESS | Total |
|---|---|---:|---:|---:|---:|---:|
| 90 | **`Ecluse.redact`** (ce que reçoit le LLM) | 269/269 | 166/166 | 214/214 | 129/129 | **778/778** |
| 60 | **`Ecluse.redact`** (ce que reçoit le LLM) | 269/269 | 166/166 | 214/214 | 129/129 | **778/778** (777/778 avant P2-158) |
| 90 | moteur seul (`ecluse_core`) | 100 % | 100 % | 87,4 % | 100 % | 96,5 % |
| 60 | moteur seul (`ecluse_core`) | 91,8 % | 90,4 % | 72,9 % | 100 % | 87,7 % |
| 90 | **détecteur isolé** (`NirDetector`, `RppsDetector`, `IbanFrDetector`, `FinessDetector` appelés directement, P2-166) | 100 % | 100 % | 87,4 % | 100 % | 96,5 % |
| 60 | **détecteur isolé** (id.) | 91,8 % | 90,4 % | 72,9 % | 100 % | 87,7 % |

Depuis le 22 novembre, les 48 IBAN à clé fausse du corpus v3 sont annotés (826
identifiants, 262 IBAN) : `Ecluse.redact` **826/826** aux deux largeurs ; moteur
seul IBAN 77,9 % (60 col.) et 89,7 % (90 col.), total 88,4 % et 96,7 % ;
détecteur isolé 682/826 et 751/826 (l'`IbanFrDetector` appelé seul écarte la clé
fausse, le moteur l'active : les deux chemins ne coïncident plus).

Le détecteur isolé (`bench/` : `run_detecteur_isole.dart`) donne exactement les
chiffres du moteur seul : l'appel direct d'un détecteur, comme dans l'exemple du
README d'`ecluse_core`, manque 96 identifiants sur 778 à 60 colonnes (22 NIR,
16 RPPS, 58 IBAN) et 27 à 90 colonnes. Chemin mesuré : appel direct, **pas** ce
que reçoit le LLM (`Ecluse.redact`, 778/778).

Collage de fin de ligne **hors du cœur** (P2-166, `run_collage_fp.dart`,
`agent/specs/P2-166.md`) : texte recollé par le banc avec la règle
d'`ecluse_redact`, détecteurs appelés seuls sur le texte recollé ; rien n'est
changé dans `lib/`. Corpus structurel : à 60 colonnes 97 coupures, 96
détections traversant une coupure (toutes sur un identifiant annoté), **0 à
tort** ; à 90 colonnes 27 coupures, 27 détections, **0 à tort**. Corpus flous,
QI, dossiers, pathologies, transcrit : 0 coupure (ils n'exercent pas ce cas).
Prose de 71 fichiers `.md` : 300 coupures, 0 identifiant formé. Cas ciblés
(« Salle 4⏎A2 », « Vol 12⏎B7 », tableau de chambres) et colonnes de nombres
uniformes à 9, 11, 13 chiffres (12 000 tirages, graine 42) : 0 détection
traversant une coupure.

Lecture : par `Ecluse.redact`, un identifiant coupé entre deux groupes est
détecté (fin de ligne neutralisée dans la vue de détection, P2-38, P2-152 et
P2-158) : les 778 identifiants sont détectés à 60 colonnes (le dernier, un IBAN
coupé avant un groupe qui commence par une lettre, « …0270⏎D932… », l'est depuis
P2-158). Le **moteur seul**
(`EcluseEngine`, sans `ecluse_redact`) n'a pas cette neutralisation : une
application qui l'appellerait directement manquerait 22 NIR, 16 RPPS et
58 IBAN à 60 colonnes. Rappel par `bench/rappel_structurel.py` (identifiant
entièrement couvert par une détection, quel qu'en soit le type). L'adversarial n'est
presque pas touché : ses textes sont courts, le recoupage n'y change que 7
espaces, ce qui ne dit rien de la robustesse des adresses. Sur le réaliste,
les noms sont stables (la civilité seule, cf. P2-12) ; les
établissements et les communes coupés en deux lignes, qui fuyaient en partie,
sont couverts depuis P2-173 (tableau ci-dessus). FINESS :
inchangé (aucun rappel perdu, 42 faux positifs SIREN comme avant).

¹ **3 refus à 60 colonnes depuis P2-173 (2 avant).** Le troisième document
contient « …, 70160 PORT SUR⏎SAONE, » : une fois la commune recollée dans la
vue de détection, la ligne retrouve la forme qu'elle a sans coupure et le
détecteur de tableaux la lit, avec ses voisines, comme un tableau à colonnes
inégales, exactement comme les deux autres documents refusés (même gabarit,
aucune ligne recollée). Rien n'est envoyé ; c'est le défaut des faux tableaux
ci-dessous, pas une règle nouvelle.
Refus explicites du détecteur de tableaux (`TableauAmbiguException`,
règle 4) : le retour à la ligne fabrique un faux tableau à colonnes
inégales ; rien n'est envoyé. Le banc `run_redact_bench.dart` les compte
désormais (`"refuse": true`) au lieu de s'arrêter ; sans cela le réaliste
à 60 colonnes ne pouvait pas être mesuré.

## Écarts avec les rapports

1. **Généralisation, F après le 1er tour** : 2 002,0 (réaliste) et 2 466,1
   (adversarial), contre 2 978,7 et 142 346,0 dans `bench/README.md` (P2-93) ;
   les 32 « non évaluable » de l'adversarial ont disparu. **Attendu** : P2-102
   (relecture des paliers d'âge et de profession) et P2-116 (département) ont
   corrigé les défauts que P2-93 mesurait. Le README garde les chiffres de
   P2-93 comme mesure d'époque.
2. **Restaurations non identiques du flou adversarial** : 61, contre 59 dans
   `bench/README.md`. **Pas une régression du code** : le code du commit
   `46b0f11` (celui qui a écrit « 59 ») donne lui aussi **61** sur le corpus
   généré aujourd'hui (même graine), et le générateur n'a pas changé depuis.
   Le chiffre 59 ne se reproduit donc pas au commit qui l'a écrit : il venait
   d'un état antérieur, que l'historique (repris à `46b0f11`) ne permet plus
   de rejouer. Le moteur actuel n'a pas régressé sur ce point ; le README est
   corrigé à 61.

Tous les autres chiffres sont identiques à ceux des rapports cités.

## Communes de 10 000 à 100 000 habitants derrière les tournures de personne (P2-238)

Mesure seule, aucune correction, aucun fichier de `lib/` modifié. `main` au
commit `3b30228`, graine 42. Chemin mesuré : **`Ecluse.redact`** (ce que reçoit
le LLM), document par document (`run_redact_bench.dart`), pas le moteur seul.

**Témoin** (`generate_corpus_tournures_communes_moyennes.py`, scoreur
`score_tournures_communes_moyennes.py`, rejoué par `bench/etat.sh`) : aucune
personne, aucune entité annotée. 60 communes tirées du référentiel versionné
(`geo_communes.csv.gz`, communes à population renseignée), **20 par tranche**
(10–30 000, 30–50 000, 50–100 000 habitants), chacune placée une fois dans les
quatre tournures de P2-220 (mêmes gabarits que P2-226) : 240 documents. Un lieu
est « masqué à tort » si une détection recouvre la commune (lisibilité perdue,
pas une fuite).

**Seuil de 100 000** : chiffré sur une **copie jetable** (arbre de travail
séparé, `communes_grandes.dart` régénéré avec `selectionne(lignes, 100000)` de
`tools/build_communes_grandes.py`), jamais commitée. La liste obtenue compte 58
noms (39 communes de 100 000 habitants et plus et 20 sans population, moins un
doublon de clé : deux communes « Saint-Denis »), et non 59.

| Tranche | Seuil 10 000 (`main`) : « à la demande de » | Seuil 100 000 : « à la demande de » | Trois autres tournures (les deux seuils) |
|---|---:|---:|---:|
| 10–30 000 | 1 / 20 | **20 / 20** | 58 / 60 |
| 30–50 000 | 0 / 20 | **20 / 20** | 60 / 60 |
| 50–100 000 | 0 / 20 | **20 / 20** | 57 / 60 |
| **Total** | **1 / 60** | **60 / 60** | 175 / 180 |

Tous les lieux masqués le sont sous le type `nom`. Les trois autres tournures
(« dossier de » 60 / 60, « entretien avec » 60 / 60, « sujet : a confirmé »
55 / 60) n'écartent aucune commune : leur chiffre ne dépend pas du seuil. Au
total, 176 lieux masqués à tort sur 240 au seuil 10 000 (`main`), 235 sur 240
au seuil 100 000.

**Lecture.**
- Au seuil de `main` (10 000), les communes de ce témoin sont à peu près toutes
  épargnées derrière « à la demande de » : 1 masquée sur 60. L'exception est
  « Roquebrune-Cap-Martin » (12 037 habitants, tranche 10–30 000), pourtant
  présente dans `communes_grandes.dart` : cause **non explorée** ici.
- Au seuil de 100 000, **les 60 communes** du témoin sont masquées derrière « à la
  demande de », dans les trois tranches (20 / 20 chacune). Le coût passe de 1 à
  60 lieux sur 60 : la tranche 50–100 000 est à **100 %**, au-dessus du
  plafond de 50 % que la fiche de P2-239 fixe pour s'arrêter.
- Ce chiffre est un coût de lisibilité sur un témoin **sans** personne : il dit
  combien de lieux de 10 000 à 100 000 habitants seraient masqués, pas combien
  de patronymes-communes seraient sauvés (24 fuites sur 96 à `main` d'après
  P2-233, 0 au seuil de 100 000). Ce compromis est celui du mainteneur.

**Ce que la mesure ne dit pas.** Les communes sont tirées au hasard (graine 42),
pas pondérées par leur fréquence d'emploi réelle ; le gabarit de « à la demande
de » est unique (« Rendez-vous reporté à la demande de X ; une nouvelle date sera
proposée ») ; aucun texte réel. Les seuils intermédiaires (30 000, 50 000) ne
sont pas chiffrés ici. La parité avec une liste réellement régénérée par le
script de P2-239 (tâche de code) n'est pas démontrée : la copie jetable utilise
la même fonction `selectionne`, donc la liste sera la même, mais le détecteur
d'une PR de code peut différer.

## Prénom + verbe conjugué : le verbe n'est plus masqué (P2-240)

Correction de `NomMinusculesDetector` (branche « prénom connu suivi d'un mot »)
et de `patronymeEtabli`. Sonde reproductible : `bench/generate_corpus_prenom_verbe.py`
(10 prénoms × 40 verbes courants = famille `courants`, 10 prénoms × 20 verbes
écrits **après** la liste = famille `reserve`, graine 42), scoreur
`score_prenom_verbe.py`, rejouée par `bench/etat.sh`. Chemin mesuré :
**`Ecluse.redact`** (ce que reçoit le LLM), document par document. Un verbe
masqué est une détection qui recouvre le verbe ; un prénom en clair serait une
fuite.

| | Avant (`main`) | Après |
|---|---:|---:|
| Famille `courants`, verbes masqués | 320 / 400 | **0 / 400** |
| Famille `reserve` (verbes hors de la liste), verbes masqués | 200 / 200 | 200 / 200 |
| Prénoms en clair (fuite), 600 phrases | 0 | 0 |

- La sonde de P2-235 donnait 340 sur 400 ; ses 40 verbes n'étaient pas versionnés,
  la nouvelle liste en donne 320 (écart de verbes, pas de code). Le « fini quand »
  « 340 → 0 » devient **320 → 0** sur la sonde versionnée.
- **Règle** : liste fermée de formes verbales courantes écrite par le projet
  (`verbes_conjugues.dart`, 177 formes) plus les terminaisons « -ait »,
  « -aient », « -erait », « -eraient », « -eront » ; un mot de la liste après un
  prénom n'est plus joint au prénom (seul le prénom est masqué, même pour un
  faux ami : « Rose rappelle. ») et n'est jamais retenu comme patronyme établi.
  Une terminaison plus large (« -ent », « -e ») est écartée : Laurent, Vincent,
  Clément ; trop de patronymes en « -e ».
- **La réserve ne mesure pas le même objet.** Une première réserve, écrite avant
  la liste, en avait reçu 15 verbes (0 / 200 : sans valeur) ; elle a été remplacée
  par 20 verbes choisis après coup et contrôlés absents (un test le vérifie). Une
  liste fermée ne couvre que ce qu'elle nomme : « Sophie sollicite. » reste masqué
  en entier (200 / 200). **L'exigence « aucun verbe masqué » n'est donc tenue que
  pour les verbes de la liste** ; l'étendre est possible, la couvrir en entier ne
  l'est pas par une liste écrite à la main.
- **Effet en chaîne** (test Dart) : « Sophie rappelle. Elle rappelle demain et il
  rappelle lundi. » garde ses trois « rappelle » ; dans un dossier, « Le médecin
  rappelle lundi. » du document suivant reste intact.
- **Fuite connue (écrite dans `LIMITES.md`)** : un patronyme homographe d'un verbe
  de la liste (« marc porte ») passe en clair derrière un prénom. **Non mesuré sur
  des patronymes réels** : aucun des 234 mots de nom annotés des corpus du dépôt
  n'est dans la liste, aucune des 177 formes n'est un prénom du gazetteer, et le
  dépôt n'a pas de référentiel de patronymes (P2-231, tâche humaine).
- **Inchangés** (tableau de bord rejoué en entier, hors cette section) : familles
  de patronymes de P2-226, témoin de P2-218, corpus de dossiers (1 / 116 manqué),
  fuite des noms du flou adversarial en minuscules, faux amis, QI, transcrits.
  Aucune fuite ajoutée sur ces témoins.
- Hors périmètre, **non traité** : la branche « civilité + prénom + mot » a le même
  défaut avec « présente » (164 occurrences dans les corpus adversariaux, P2-235) ;
  la corriger changerait des chiffres du flou adversarial.

## Après « à la demande de » : seules les communes de 100 000 habitants et plus sont écartées (P2-239)

Correction de `NameDetector` : la table `communes_grandes.dart` (générée par
`tools/build_communes_grandes.py`, test de parité Python) passe du seuil de
10 000 habitants à **100 000** (58 noms, les communes sans population
renseignée comprises), conformément à la décision du 20 novembre. Elle ne sert
toujours qu'après « à la demande de ». Chemin mesuré : **`Ecluse.redact`** (ce
que reçoit le LLM), document par document (`run_redact_bench.dart`) ; « en
session » = `Dossier`. Test écrit d'abord (4 cas « masqué » en échec sur
`main`, `tournure_communes_seuil_test.dart`). Tableau de bord complet
(`bench/etat.sh`) rejoué avant (`1f553f5`) et après, graine 42.

| Mesure (`Ecluse.redact`, graine 42) | Avant (`main`) | Après |
|---|---:|---:|
| P2-226, `patronymes_communes` (annotés `nom`), « à la demande de » : en clair (fuite) | 24 / 24 | **0 / 24** |
| P2-226, `patronymes_communes`, les 4 tournures : en clair (fuite) | 24 / 96 | **0 / 96** |
| P2-218, patronyme seul, « à la demande de » : manqués document par document | 1 / 19 | **0 / 19** |
| P2-218, patronyme seul, 116 mentions : manquées document par document / en session | 1 / 0 | **0 / 0** |
| P2-218, témoin sans nom, `lieu` : masqués à tort | 60 / 100 | 61 / 100 |
| P2-226, `organismes` (« Orange », commune de plus de 10 000) : masqués à tort | 43 / 96 | 44 / 96 |
| P2-238, communes de 10 000 à 100 000, « à la demande de » : masquées à tort | 1 / 60 | **60 / 60** |
| P2-238, idem par tranche (10–30 000, 30–50 000, 50–100 000) | 1, 0, 0 sur 20 | 20, 20, 20 sur 20 |
| P2-238, toutes tournures : lieux masqués à tort | 176 / 240 | 235 / 240 |

- **Égal à la simulation de P2-238** : 60 / 60 derrière « à la demande de »
  (20 par tranche), 235 sur 240 au total ; les trois autres tournures
  (175 / 180) ne changent pas.
- **Ce que ça coûte** (assumé, décision du 20 novembre, écrit dans
  `LIMITES.md`) : toute ville de 10 000 à 100 000 habitants est masquée après
  « à la demande de » ; le témoin n'a aucune personne, c'est de la lisibilité
  perdue, pas une fuite. Le plafond de 50 % de la fiche est levé par la
  décision.
- **Ce que ça rapporte** : 24 fuites sur 96 → 0 au témoin de P2-226 et le dernier
  patronyme seul manqué du corpus de dossiers (« à la demande de Gaillard »).
- **Contre-effet non mesuré sur des cas réels** : un patronyme qui est aussi une
  commune de **100 000 habitants et plus** (« Rouen », « Brest ») reste lu
  comme un lieu derrière « à la demande de » ; aucun mot du témoin de P2-226 n'en
  est un, donc ce témoin ne le voit pas.
- **Inchangés** (tableau de bord rejoué en entier, diff ligne à ligne avec la
  sortie d'avant) : tous les autres chiffres, dont corpus de dossiers (hors le
  patronyme seul ci-dessus), flou adversarial, QI, adresses, identifiants,
  pathologies, prénom + verbe (P2-240), mise en page.
- La seule autre ligne du témoin de P2-226 qui bouge est `organismes` (+1 :
  « Orange »), soit la marque qui est aussi une commune de plus de 10 000
  habitants, déjà signalée par `LIMITES.md`.
## Prénom + verbe : liste de verbes étendue (P2-242)

Correction de `verbes_conjugues.dart` (liste fermée étendue de 177 à 558
formes, terminaisons et formes dérivées) ; `NomMinusculesDetector` inchangé.
Sonde : `bench/generate_corpus_prenom_verbe.py`, désormais **trois familles**
(graine 42) : `courants` (400), `reserve` (200, P2-240) et `reserve2` (680 =
10 prénoms × 68 verbes de l'écrit soignant et social, **écrite avant la liste**
et jamais reprise dans la liste, un test le contrôle). Chemin mesuré :
**`Ecluse.redact`**, document par document ; un verbe masqué est une détection
qui recouvre le verbe.

| | Avant (`main`) | Après |
|---|---:|---:|
| `courants`, verbes masqués | 0 / 400 | **0 / 400** |
| `reserve` (P2-240), verbes masqués | 200 / 200 | **180 / 200** |
| `reserve2` (P2-242), verbes masqués | 660 / 680 | **630 / 680** |
| Prénoms en clair (fuite), 1 280 phrases | 0 | **0** |

- **Le critère « réserve au plus 100 sur 200 » n'est pas atteint** (180). Une
  liste fermée ne généralise presque pas : 344 verbes ajoutés (558 formes au total) écrits par champ
  lexical, sans les 20 verbes de `reserve` ni les 68 de `reserve2`, en couvrent
  20 sur 200 et 30 sur 680. Atteindre 100 sur 200 sans reprendre les verbes de la
  réserve est contradictoire avec la consigne « ne pas reprendre mot à mot » ;
  la voie qui généralise est la règle de forme (P2-241, bloquée à +25,9 %) ou un
  référentiel de patronymes (P2-231). À décider par le mainteneur.
- Terminaisons ajoutées, **une à la fois**, mesurées avec
  `bench/mesure_terminaisons_verbes.py` contre les mots des entités `nom` de tous
  les corpus du dépôt (107 mots de plus de 4 lettres) et les prénoms INSEE
  d'effectif au moins 1 000 (2 859) : « -ifie », « -ionne », « -ifient »,
  « -ionnent », « -isent », « -issent », « -ivent », « -iera » : 0 nom annoté, 0
  prénom. Écartées : « -ise » (0 nom annoté mais 25 prénoms : Louise, Denise),
  « -era » (Herrera), « -dra » (Sandra), « -ère », « -ite », « -ige », « -are »,
  « -ule », « -ent » (2 noms), « -ume » (1 nom), « -ure » (2 noms).
- Formes dérivées : pluriel (base + « nt ») et futur (base + « ra ») d'un verbe de la
  liste en « -e » ; jamais d'un mot quelconque en « -ent » ou « -era » (Laurent,
  Parent, Herrera). Un test Dart et un test Python vérifient qu'aucune forme
  reconnue n'est un nom annoté ni un prénom courant.
- **Reste du tableau de bord : identique ligne à ligne** à un rejeu de `main`
  (diff des deux sorties de `bench/etat.sh` : seules les lignes de la sonde
  changent). Noms en clair (entier ou en partie), corpus flous et de dossiers :
  inchangés.
- Limite de la mesure : les corpus du dépôt n'ont que 107 mots de nom de plus de
  4 lettres ; un compte nul ne prouve rien sur de vrais patronymes. La fuite par
  homographe (« marc dispose », « julien observe ») n'est pas mesurée.

## « Prénom + mot » en minuscule : mesure préalable de P2-241 (arrêt, aucun code livré)

Mesure préalable exigée par la fiche (« combien de noms annotés `Prénom nom-en-minuscule`
dans un texte à casse normale passeraient en clair ? »), faite par un **essai jetable**
de la règle décidée (dans `NomMinusculesDetector`, branche « prénom connu suivi d'un
mot » : si le texte contient au moins une majuscule et que le mot suivant est en
minuscule, seul le prénom est masqué), **retiré ensuite**. Aucun fichier de `lib/` n'est
modifié par cette PR. Chemin mesuré : **`Ecluse.redact`** (ce que reçoit le LLM),
document par document, `main` au commit `1f553f5`, graine 42. Un nom « passe en
clair » ici = au moins une lettre de son intervalle annoté n'est couverte par aucune
détection ; le chiffre est donné en **écart** avant → après (la mesure brute compte
aussi les civilités annotées dans l'intervalle, d'où des valeurs de base élevées sur
le corpus réaliste, inchangées).

| Corpus (`flou`, 594 noms) | Noms en partie en clair, avant → après | en entier en clair |
|---|---:|---:|
| adversarial, casse de phrase | 121 → **275** (**+154, 25,9 %**) | 44 → 47 |
| adversarial, mixte | 117 → **157** (**+40, 6,7 %**) | 36 → 38 |
| adversarial, minuscules / majuscules / ordinaire | inchangé | inchangé |
| réaliste (479 noms), toutes casses | inchangé | inchangé |

Tableau de bord complet rejoué avec l'essai : sonde `prénom + verbe`, famille
`reserve` **200 → 0 sur 200** (objectif atteint), famille `courants` 0 ; en
revanche, au score strict, rappel `nom` du corpus adversarial en casse de phrase
**61,3 % → 17,3 %** (F1 63,9 → 16,6). Les corpus de dossiers : cohérence des noms
un peu meilleure (18 → 16 sur 161 ; 24 → 22 sur 128), sans mesure de fuite propre.

**Verdict.** Le seuil d'arrêt de la fiche (plus de 1 % des noms d'un corpus existant
rendus en clair) est dépassé d'un facteur 7 à 26 sur deux corpus : la tâche
s'arrête, conformément à la fiche et à `CLAUDE.md`. Cause : en casse de phrase, ces
corpus écrivent *tous* les patronymes en minuscule (« julien chevrier ») ; la règle
ne peut pas distinguer ce patronyme d'un verbe (« sophie rappelle »), car la forme
(minuscule après un prénom) est la même. L'objectif « aucun verbe masqué » et
« aucune fuite ajoutée » ne sont pas tenables ensemble par une règle de forme seule.
Pistes à décider par le mainteneur : liste fermée plus large (P2-240) complétée par
des terminaisons verbales, ou règle de forme **limitée** (texte à casse de phrase *et*
mot absent d'une liste de patronymes, P2-231), ou accepter le coût chiffré ici.

## Liste de patronymes fournie par l'application, dans le `Dossier` (P2-243)

Protocole de la § 7 de `agent/specs/P2-219.md`. Chemin mesuré :
**`Ecluse.redact`** avec `Dossier(patronymesConnus: …)` (ce que reçoit le LLM), `main`
au commit `f7a94bb` plus cette PR, graine 42. Tout est synthétique : les patronymes
viennent des listes du générateur, 10 000 noms de remplissage sont tirés par syllabes
(`bench/export_patronymes_dossiers.py`) ; aucune liste réelle. « Liste exacte » = les
patronymes des personnes du dossier ; « large » = toutes les personnes du corpus, les
patronymes du générateur qui sont des mots courants et 10 000 noms tirés au hasard
(10 042 distincts) ; « sans » = la liste large privée des personnes du dossier.
Rejoué par `bench/etat.sh` (section « liste de patronymes de l'application »).

| Mesure (corpus, chemin) | Sans liste | Exacte | Large | Sans la bonne personne |
|---|---:|---:|---:|---:|
| Patronyme seul en **première mention**, corpus `b` (400 mentions) : détecté / annoté | 196 / 400 | **400 / 400** | **400 / 400** | 196 / 400 |
| Leurres (mot courant du dossier, 265 documents seuls dans leur dossier) : masqués à tort | 0 / 265 | **265 / 265** | **265 / 265** | 0 / 265 |
| Corpus de dossiers réaliste (116 patronymes seuls) : manqués en session | 0 | 0 | 0 | 0 |
| Témoin sans personne (tournures, 400 documents) : documents avec un nom masqué | 141 / 400 | — | 141 / 400 | — |

Lecture, sans en tirer plus qu'elle ne dit :

- **Gain réel, en première mention sans tournure reconnue** : 204 noms sur 400 en
  clair sans liste (66/201 en début de phrase, 130/199 au milieu détectés), 0 avec la
  liste exacte ou large. Une liste **sans la bonne personne** ne change rien (196/400
  comme sans liste), ce qui est attendu : la liste n'ajoute que ce qu'elle contient.
- **Aucun gain sur le corpus de dossiers réaliste** : le patronyme seul manqué y est
  déjà à 0 sans liste au rejeu de ce jour (112 sans règle au départ de P2-218, 4 après
  P2-220). La liste ne s'y mesure donc pas ; le seuil « liste exacte → 0 manqué » est tenu trivialement.
- **Le seuil « au plus 1 % de phrases masquées à tort » n'est pas tenable pour un mot
  courant fourni comme nom** : 265 / 265 phrases de leurres masquées quand la liste
  contient le mot (« Petit déjeuner », « Marchand de journaux »). C'est le sur-masquage
  assumé de la spec (§ 3) et de `LIMITES.md` § 8 ; ici l'application le déclenche en
  fournissant le nom. Sur le **témoin sans personne** (141 / 400 déjà masqués sans
  liste, faux positifs existants des tournures), la liste large n'ajoute **aucun**
  masquage (141 / 400) : ce témoin ne contient pas les mots de la liste ; il ne dit
  donc rien du sur-masquage d'un mot courant (voir la ligne des leurres).
- **Équivalence** : sans liste, le reste du tableau de bord est identique au rejeu de
  `main` (diff du rejeu complet : seules les lignes de cette section sont ajoutées).
  Test d'équivalence unitaire : `packages/ecluse_redact/test/patronymes_connus_test.dart`.

**Coût** (§ 7.4), `bin/run_patronymes_cout.dart`, 397 documents du corpus réaliste,
un `Dossier` neuf par dossier, trois répétitions, médiane (étendue), noms
**distincts** ; temps non déterministes, donc **hors de `etat.sh`**, une seule
machine de développement cloud :

| Noms dans la liste | Temps de la passe | Mémoire résidente maximale |
|---:|---:|---:|
| 0 | 553 ms (526–736) | 321 Mio |
| 100 | 531 ms (506–766) | 331 Mio |
| 1 000 | 743 ms (607–953) | 327 Mio |
| 10 000 | **1 615 ms** (1 582–1 924) | 347 Mio |

Le coût est linéaire en la taille de la liste **à chaque pièce** (copie de l'ensemble
par appel, `NameDetector` le recopie) : environ 2,7 ms de plus par document à 10 000
noms, soit environ trois fois le temps sans liste. La spec attendait « nul si la copie
est faite une seule fois » ; elle ne l'est pas (voir « Ce qui reste incertain » de la PR).

**Ce que la mesure ne dit pas** : le comportement sur de vraies listes de patients
(jamais disponibles ici, règle 1 de `CLAUDE.md`) ; la fréquence réelle de patronymes
seuls hors tournure dans des textes réels ; des noms de plusieurs mots ou à particule
(non rattrapés, `LIMITES.md` § 8) ; le temps sur des documents plus longs que ceux du
corpus.
## Communes en capitales écrites hors référentiel : « ST », séparateurs collés (P2-244)

Option 1 de `agent/specs/P2-215.md`, table réduite seulement (décision du 21 novembre). La
règle « nom exact » lit « ST »/« STE » comme « SAINT »/« SAINTE » et compare les noms
collés (apostrophe ou tiret perdu sans espace). Chemin mesuré : **`Ecluse.redact`**
(prédictions de `run_redact_bench.dart`) ; une adresse par commune et par écriture, 261
communes des formes A, C et D, tout en capitales, sans CEDEX, graine 42 ; `main` au commit
`f7a94bb` plus cette PR. Les colonnes « règle simulée » de `ecritures_hors_referentiel.py`
sont des simulations hors `lib/` (`resolveOverlaps` non rejoué) ; la colonne « code livré »
est la mesure réelle. Rejoué par `bash bench/etat.sh` (section « communes en capitales hors
référentiel »).

| Écriture | Adresses | En partie en clair, avant | **après** |
|---|---:|---:|---:|
| référence (forme postale), contrôle | 261 | 0 | 0 |
| accents gardés, contrôle | 80 | 0 | 0 |
| « ST », « STE » pour SAINT, SAINTE | 170 | 66 | **0** |
| apostrophe perdue, mots collés | 69 | 9 | **0** |
| tiret perdu, mots collés | 246 | 33 | **0** |
| une lettre fautive | 261 | 143 | 143 (non traité) |
| une lettre omise | 261 | 141 | 141 (non traité) |
| **cinq écritures hors référentiel** | **1 007** | **392** | **284** |

Écart avec la fiche : la fiche écrit « 388 → 280 au plus ». Le départ mesuré aujourd'hui
sur `main` est **392**, non 388 (les deux écritures par lettre valaient 141 et 139 dans la
spec, 143 et 141 aujourd'hui : elles ont bougé depuis la spec, hors de cette tâche). L'option
1 ne touche pas à ces deux écritures : 392 − 66 − 9 − 33 = **284**, et la simulation
`normalise` de la spec donne le même chiffre sur le même corpus. Le seuil « 280 au plus »
n'est donc pas atteint par la seule option 1 ; le critère de fond (les trois écritures à
0) l'est.

**Témoins** (lignes sans adresse, `Ecluse.redact`) : cinq chiffres, déterminant, mot neutre
devant CEDEX, courriers, noms de forme neutre, communes moyennes, tournures : **identiques**
au rejeu de `main` (diff du rejeu complet de `etat.sh` : seules les lignes de la nouvelle
section sont ajoutées). Un test de non-régression existe pour « LES PLACES » (coût connu).

**Ce que la mesure ne dit pas** : une fréquence (personne n'a compté combien d'adresses
réelles écrivent « ST »), les abréviations autres (« ST. », « S/ », « STS »), deux fautes dans
un nom, les anciens noms de communes ; le risque propre à la comparaison collée sur des noms
longs (un témoin de phrases en capitales de cinq mots ou plus derrière un nombre à cinq
chiffres est recommandé par la spec avant l'option 2, non construit ici).

## IBAN de forme française à clé fausse masqué en entier (P2-252, 22 novembre 2026)

Décision du 22 novembre : un IBAN mal recopié reste celui de quelqu'un. Les IBAN
« pièges » du corpus (`trap_iban`, clé fausse, avec ou sans libellé) sont masqués
en entier, type `iban`, confiance 0,3, avertissement « à vérifier ». Rejeu complet
de `bench/etat.sh` sur `main` (`8387b39`) puis sur la branche : seules ces lignes
changent, toutes attendues.

**Défaut mesuré (corpus d'identifiants, graine 42, 200 000 documents, 8 362 IBAN
pièges).** Chemin **moteur seul** (`run_ecluse.dart`) : 10 masqués en partie
(FINESS), 8 352 en clair → 0 en partie, 8 362 en entier. Chemin **`Ecluse.redact`**
(`run_redact_bench.dart`) : 43 masqués en partie (FINESS ou téléphone), 2 762 en
clair, 5 557 en entier → 0, 0, 8 362. Rappel NIR, RPPS, IBAN, FINESS : 100 % avant
et après ; fuite au caractère 0 % partout.

**Ce qui change au tableau de bord** (les corpus qui contiennent ces témoins comme
négatifs les comptent maintenant en faux positifs, ce qui est le sur-masquage voulu) :

| Ligne | Avant | Après | Chemin |
|---|---|---|---|
| v3, précision / F1 / FP | 94,9 % / 97,4 % / 42 | 89,6 % / 94,5 % / 90 | moteur seul |
| v3, IBAN précision (200 000 docs) | 100 % | 83,3 % | moteur seul |
| libellé fort, négatifs masqués | 8 / 1 200 | 53 / 1 200 | `Ecluse.redact` |
| libellé fort, `nombre_sans_libelle` | 8 / 300 | 53 / 300 | `Ecluse.redact` |
| libellé fort, négatifs au libellé IBAN | 1 / 200 | 46 / 200 | `Ecluse.redact` |
| mise en page, 60 colonnes, précision IBAN / total | 100 % / 93,3 % | 76,5 % / 87,5 % | moteur seul |
| mise en page, 90 colonnes, précision IBAN / total | 100 % / 94,3 % | 79,6 % / 89,0 % | moteur seul |

Les rappels de la mise en page (72,9 % et 87,4 % pour l'IBAN) ne changent pas. Les
45 nouveaux « masqués à tort » du corpus libellé fort portent tous l'avertissement
(confiance 0,3 : 45 sur 1 200 négatifs). Presidio n'est pas rejoué.


## IBAN à clé fausse annotés comme données personnelles (22 novembre 2026)

Décision du mainteneur du 22 novembre (`DECISIONS.md`) : les 48 IBAN « pièges »
à clé fausse du corpus v3 (« L'IBAN … a été refusé par la banque », 8 362 sur
200 000 documents) sont **annotés** `iban` par `bench/generate_corpus.py`. Le
texte des documents est inchangé (vérifié octet pour octet sur 1 000 et
200 000 documents) ; seule l'annotation est ajoutée. Rejeu complet de
`bench/etat.sh` avant et après : seules les lignes ci-dessous changent.

| Ligne | Avant | Après | Chemin |
|---|---|---|---|
| v3, entités annotées (1 000 docs) | 778 (214 IBAN) | 826 (262 IBAN) | — |
| v3, précision / F1 / FP | 89,6 % / 94,5 % / 90 | 95,2 % / 97,5 % / 42 | moteur seul |
| v3, IBAN précision (200 000 docs) | 83,3 % | 100 % | moteur seul |
| Presidio, rappel IBAN / total (1 000 docs) | 68,7 % / 18,9 % | 56,1 % / 17,8 % | Presidio tel que livré |
| Presidio, rappel IBAN / total (200 000 docs) | 66,6 % / 18,5 % | 55,5 % / 17,5 % | Presidio tel que livré |
| mise en page 60 col., IBAN préc. / rappel | 76,5 % / 72,9 % | 100 % / 77,9 % | moteur seul |
| mise en page 90 col., IBAN préc. / rappel | 79,6 % / 87,4 % | 100 % / 89,7 % | moteur seul |

Presidio n'est pas rejoué : ses prédictions du 21 novembre (`c3de6a8`) sont
rescorées sur la nouvelle annotation. Son recognizer IBAN écarte la clé fausse :
il manque les 48 (1 000 documents) et 8 362 (200 000) IBAN à clé fausse, en plus
de ceux à blancs irréguliers. Le corpus « libellé fort » garde ses IBAN à clé
fausse comme négatifs (générateur à part, non modifié).

## Corpus « libellé fort » : IBAN à clé fausse sans libellé annotés (22 novembre 2026)

Même règle que pour le corpus v3 (`DECISIONS.md`, 22 novembre, point 8) : les
50 IBAN à clé fausse sans libellé (`nombre_sans_libelle` tiré pour l'IBAN) sont
annotés `iban` et comptés comme positifs (`sans libellé x
cle_fausse_sans_libelle`). Texte des 3 000 documents inchangé ; prédictions de
`Ecluse.redact` identiques, seul le score change.

| Ligne | Avant | Après |
|---|---|---|
| positifs / en clair | 1 800 / 0 | 1 850 / **4** |
| témoins négatifs masqués à tort | 53 / 1 200 | 7 / 1 150 |
| `nombre_sans_libelle` masqués à tort | 53 / 300 | 7 / 250 |
| négatifs au libellé IBAN masqués à tort | 46 / 200 | 0 / 150 |
| avertissement « à vérifier » sur les négatifs | 45 / 1 200 | 0 / 1 150 |

**Défaut révélé** : les 4 IBAN en clair ont tous une lettre « o » ou « O » à la
place d'un chiffre de la clé (« FR8o52… », « FRo6… ») ; `IbanCleInvalideDetector`
exige deux chiffres après `FR`, et sans libellé fort la tolérance d'OCR de
P2-191 ne s'applique pas. Toléré par un plafond de 4 dans
`PLAFOND_LIBELLE_FORT` (`bench/etat_attendu.py`), correction inscrite en P2-254.
Le scoreur n'imprime plus les cases vides (libellé × variante sans positif).

## IBAN à clé fausse, lettre « o » dans la clé, sans libellé (P2-254)

Chemin mesuré : `Ecluse.redact` (chemin du produit), corpus « libellé fort »,
graine 42, 50 documents par case ; `bash bench/etat.sh` rejoué en entier avant
(`main`, 4b8458d) et après la correction. Seule la clé de `IbanCleInvalideDetector`
admet désormais « o » / « O » à la place d'un chiffre.

| mesure | avant | après |
|---|---|---|
| `sans libellé x cle_fausse_sans_libelle` en clair | 4 / 50 | 0 / 50 |
| identifiants positifs en clair (libellé fort) | 4 / 1 850 | 0 / 1 850 |
| `nombre_sans_libelle` masqués à tort (témoins) | 7 / 250 | 7 / 250 |
| avertissement « à vérifier » sur les négatifs | 0 / 1 150 | 0 / 1 150 |
| témoin sans donnée personnelle (480 documents, `comparatif.py --temoin`, `Écluse document par document`) | 16 / 480 masqués | 16 / 480 masqués |

Les 12 autres lignes qui changent entre les deux rejeux sont les conséquences
directes des 4 identifiants désormais masqués (confiance 0,3 : 1 495 → 1 499 ;
avertissement : 1 545 → 1 549 ; variante : 45 → 49 sur 50). Aucune autre ligne du
tableau de bord ne bouge. `PLAFOND_LIBELLE_FORT` est retiré (vide).

## NIR à clé fausse sans libellé masqué en entier (P2-258, 23 novembre 2026)

Décision du 23 novembre (point 1) : un NIR mal recopié reste celui d'un patient.
`NirCleInvalideDetector` : quinze caractères de la forme d'un NIR (sexe 1 ou 2,
mois, département et ordre plausibles, lettre « O » admise à la place d'un zéro),
**clé fausse**, masqué en entier, type `nir`, confiance 0,3, avertissement « à
vérifier ». Appelé par `Ecluse.redact` sur le **texte d'origine** (comme
`IdentifiantCleInvalideDetector`), pas sur la vue de détection : la clé nommée à
part fausse de P2-42 (« 2550814168025 clé 39 ») reste intacte. Les coupures du
numéro doivent tomber entre les groupes d'un NIR (1-2-2-2-3-3-2) ; sans cette règle,
un RPPS suivi d'un nombre de quatre chiffres (« 10192209566 1250 places ») était
avalé en « NIR » (première version : `identifiant suivi` 2 → 19 défauts, corrigé
avant la PR). Rejeu complet de `bench/etat.sh` sur `main` (`21764b2`) puis sur la
branche : seules les lignes ci-dessous changent, toutes attendues ; 0 ligne
« ÉCHEC ».

**Coût mesuré sur les témoins** : aucun témoin négatif du tableau de bord ne gagne
un masquage (libellé fort : les 3 témoins masqués restants sont les mêmes
collisions de hasard qu'avant, confiance 0,55 ; `comparatif.py --temoin` :
16 / 480 avant et après, `Ecluse.redact`). Les quatre négatifs « NIR sans libellé »
qui comptaient dans les 7 d'avant sont devenus des positifs annotés.

| Ligne | Avant | Après | Chemin |
|---|---|---|---|
| v3, entités / précision / F1 | 826 / 95,2 % / 97,5 % | 871 / 95,4 % / 97,6 % | moteur seul |
| v3, NIR rappel `Ecluse.redact` | 269 / 269 | 314 / 314 | `Ecluse.redact` |
| v3, mise en page 60 colonnes, NIR manqués | 22 sur 269 | 23 sur 314 | moteur seul |
| v3, mise en page 90 colonnes, NIR | 269 TP | 314 TP | moteur seul |
| libellé fort, positifs / témoins | 1 850 / 1 150 | 2 000 / 1 000 | `Ecluse.redact` |
| libellé fort, `sans libellé` × `cle_fausse_sans_libelle` | 0 / 50 en clair | 0 / 200 en clair | `Ecluse.redact` |
| libellé fort, témoins masqués à tort | 7 / 1 150 | 3 / 1 000 | `Ecluse.redact` |
| identifiant suivi, défauts | 2 / 4 800 | 2 / 4 800 (inchangé) | `Ecluse.redact` |

Les NIR pièges de v3 (45) et d'extended (29), et les 150 NIR « sans libellé » du
corpus libellé fort sont annotés `nir`, texte inchangé octet pour octet (empreinte
SHA-256 des 1 000 textes v3 identique). Presidio rejoué pour `bench/README.md` : NIR
`validated` 100 % / 100 % → 100 % / 85,7 % (voir ce fichier).

**Non couvert** (écrit dans `LIMITES.md` § 2) : NIR à clé fausse écrit en groupes
d'une autre taille (par exemple 3 × 5), NIR à clé **juste** avec lettres « O » sans
libellé (comme avant, P2-191), NIR à clé fausse dont les chiffres sont écrits en
pleine chasse ou séparés par une fin de ligne (le détecteur lit le texte d'origine).

## SIRET nommé masqué en entier (P2-259, 23 novembre 2026)

Décision du 23 novembre (point 3) : quatorze chiffres après le mot « SIRET » sont
une donnée personnelle (le SIRET contient le SIREN). `FinessDetector` lit en plus
quatorze chiffres (collés, ou 3-3-3-5) à moins de 40 caractères du mot « SIRET » :
type `siren`, confiance 0,9 si la clé de Luhn est juste, 0,3 (avertissement « à
vérifier ») si elle est fausse. Rejeu complet de `bench/etat.sh` après P2-258
(rebasé sur `main` à la fusion) : 0 ligne « ÉCHEC » ; seules les lignes ci-dessous
changent.

**Défaut mesuré** (`bench/recensement_pieges.py`, `Ecluse.redact`) : SIRET pièges
v3 30 en clair → **0** (30 masqués en entier, type `siren`) ; extended 19 → **0**.

**Ce qui change au tableau de bord** (chiffres après P2-258 : 871 entités ; les
colonnes « Avant » des mises en page ne sont pas citées, elles n'ont pas été
rejouées entre les deux tâches) : le SIRET n'est pas annoté (décision du
23 novembre, point 5, pour garder quatre types au banc), donc chaque SIRET masqué
compte comme un faux positif `siren`, comme les 42 SIREN pièges.

| Ligne | Avant | Après | Chemin |
|---|---|---|---|
| v3, précision / F1 / FP | 95,4 % / 97,6 % / 42 | 92,4 % / 96,0 % / 72 | moteur seul |
| v3 à 60 colonnes, total précision / F1 / FP | — | 90,7 % / 89,8 % / 79 | moteur seul |
| v3 à 90 colonnes, total précision / F1 / FP | — | 91,8 % / 94,3 % / 75 | moteur seul |
| extended, FP `siren` / total précision | 131 / 74,0 % | 150 / 72,6 % | moteur seul |
| témoin flou (400 documents), prédictions | 0 | **108** | `Ecluse.redact` |

Les rappels, la fuite au caractère, le tableau « libellé fort », « identifiant
suivi » et les autres témoins sont inchangés. **Les 108 prédictions du témoin
flou** sont toutes de type `siren` et toutes sur la ligne « SIRET 12345678200010 »
des 108 documents de la variante « identifiants d'entreprise » du générateur
(`generate_corpus_flou.py`) : ce gabarit était un témoin « rien à masquer » avant
la décision du 23 novembre ; il est maintenant masqué à dessein. Le témoin n'a pas
été modifié (cela changerait le texte des 400 documents et tous les chiffres qui
en dépendent) ; la tâche suivante est à décider par le mainteneur. Sa ligne
« TVA FR11123456782 » reste en clair (P2-260).
`comparatif.py --temoin` : 16 / 480 documents masqués avant et après.

## Numéro de TVA intracommunautaire masqué en entier (P2-260, 23 novembre 2026)

Décision du 23 novembre (point 4) : « FR » + clé + SIREN est une donnée personnelle.
`FinessDetector` lit « FR » + clé de deux caractères + neuf chiffres (blancs simples
admis) : type `siren`, clé calculée `(12 + 3 × (SIREN mod 97)) mod 97` juste →
confiance 0,9 ; fausse ou à lettre → seulement avec « TVA » ou « intracommunautaire »
à moins de 40 caractères, 0,3 et avertissement « à vérifier ». L'entité (13
caractères) l'emporte sur le RPPS de onze chiffres. Rejeu complet de `bench/etat.sh`
après P2-258 et P2-259 (rebasé sur `main` à la fusion) : 0 ligne « ÉCHEC » ; seules les lignes
ci-dessous changent.

**Défaut mesuré** (`bench/recensement_pieges.py`, `Ecluse.redact`, extended) : TVA
29 en clair + 6 masqués en partie (RPPS) → **35 en entier**, type `siren`. Aucun
RPPS du corpus ne change de type (117 / 117).

| Ligne | Avant | Après | Chemin |
|---|---|---|---|
| extended, RPPS précision / FP | 95,1 % / 6 | **100 % / 0** | moteur seul |
| extended, FP `siren` | 150 | 185 | moteur seul |
| extended, total précision / F1 | 72,6 % / 81,0 % | 70,6 % / 79,8 % | moteur seul |
| témoin flou (400 documents), prédictions | 108 (SIRET) | **216** | `Ecluse.redact` |
| `comparatif.py --temoin` | 16 / 480 | 16 / 480 | `Ecluse.redact` |

Le corpus v3 ne contient aucune TVA : ses lignes sont inchangées, de même que
« libellé fort », « identifiant suivi » et les autres témoins. **Les 108 prédictions
du témoin flou** sont toutes de type `siren`, toutes sur « TVA FR11123456782 »
(clé juste), ligne du gabarit « identifiants d'entreprise » de
`generate_corpus_flou.py` : ancien témoin « rien à masquer », masqué à dessein
depuis la décision du 23 novembre (P2-259 y masque aussi « SIRET 12345678200010 » :
216 prédictions si les deux sont fusionnées). Le témoin n'a pas été modifié.

## Garde du mot voisin : avertissement distinct (P2-299, 26 novembre 2026)

Décision du 26 novembre, point 3. Chemin mesuré : `Ecluse.redact`
(`run_temoin_nombres_dictes.dart`), graine 42, corpus
`generate_corpus_mot_voisin.py` (87 780 documents, deux modes). Avant : la garde
de P2-282 coupait le signalement « nombre dicté non reconnu » et rien ne le
remplaçait. Après : un avertissement distinct, « suite de nombres dictés
précédée d'un mot comme « code » : non masquée, à vérifier » (positions et
compte, jamais la valeur).

| Mesure | Avant | Après |
|---|---|---|
| Identifiants signalés au témoin, sans libellé, ≤ 100 caractères : passés à « rien » | **6 214** / 6 580 | **0** / 6 580 |
| … portés par l'avertissement distinct | 0 | 6 214 |
| Signalements « nombre dicté non reconnu » à tort : durci / neuf / d'origine | 0 / 0 / 0 | 0 / 0 / 0 |
| Avertissements distincts sur ces témoins (phrases ordinaires) | — | **49** / 41 / 0 |
| Avec libellé (« code iban »), ≤ 100 : passés à « rien » | 0 | 0 |

Prédictions de tous les autres corpus identiques octet pour octet
(`bench/equivalence_predictions.sh` : 72 fichiers identiques ; 5 différents comme
prévu, ne différant que par le champ `signalements_mot_voisin` ou par les lignes
« signalements à tort », sans changement d'entité). Les 49 / 41 avertissements des
témoins sont les phrases que le signalement ordinaire signalait à tort avant P2-282 :
le prix de la garde est un message moins pressant sur des codes d'accès.

## « Type + mot générique » : liste fermée (P2-301, 26 novembre 2026)

Chemin mesuré : **`Ecluse.redact`** (`run_redact_bench.dart`), graine 42, sur le code
de la tâche contre `main` au commit `fe92420`. Ces trois lignes ne sont pas dans
`bench/etat.sh` (200 000 documents, ≈ 5 min) ; elles se rejouent avec
`bench/mesure_type_mot_generique.sh` (P2-295) en lisant la colonne « generiques ».

| mesure | avant | après |
|---|---|---|
| 200 000 phrases du soin sans personne : documents avec un établissement masqué | 2 063 | 0 |
| témoin de 480 documents (`comparatif.py --temoin`, Écluse) : masqués à tort | 9 / 480 | 0 / 480 |
| flou réaliste + adversarial, 7 présentations : établissements annotés couverts / bornes exactes | 3 595 / 3 305 | 3 595 / 3 305 |
| corpus principal (v3, 1 000 documents) : documents avec un établissement masqué | 91 | 91 |

Le tableau de bord complet (`bench/etat.sh`) rejoué : `bench/controle_etat.py` le
déclare conforme au bloc courant ; aucun chiffre ne bouge. La liste est dans
`EtablissementDetector.motsGeneriques` ; sa limite est dans `LIMITES.md` § 5.1.

## Valeurs courantes contrôlées (P2-265, 23 novembre 2026)

Tout ce qui précède est de l'**historique daté** : des tableaux écrits section
par section, jamais comparés d'un bloc à la sortie d'`etat.sh`. Le bloc
ci-dessous est la seule partie **courante** : l'extrait verbatim de la sortie
d'`etat.sh` (espaces écrasés, ligne `## commit` exclue) au commit où il a été
rejoué. `python3 bench/controle_etat.py etat.log` compare chaque ligne à la
sortie, dans l'ordre et sous le même titre, et sort en erreur au premier écart
en montrant la ligne fautive. Après une tâche qui change une mesure : rejouer
`etat.sh`, puis `python3 bench/controle_etat.py --propose etat.log` imprime le
bloc à recoller entre les deux marqueurs (les tableaux d'historique
au-dessus n'ont pas à être touchés par ce script).

<!-- controle:debut -->
```
## v3 (identifiants structurels)
Ecluse TOTAL 100.0% 100.0% 100.0% 943 0 0
Ecluse TOTAL 100.0% 100.0% 100.0% 943 0 0
Ecluse (c) COMMUNS 100.0% 100.0% 100.0% 871 0 0
Ecluse (c) COMMUNS 100.0% 100.0% 100.0% 871 0 0
Ecluse (e) strict 100.0% 100.0% 100.0% 72 0 0
Ecluse (e) souple 100.0% 100.0% 100.0% 72 0 0
## v3 transcrit
# sans_ponctuation
Ecluse TOTAL 100.0% 100.0% 100.0% 943 0 0
# en_lettres
Ecluse TOTAL 0.0% 0.0% 0.0% 0 0 943
## v3 dictée : variantes de P2-160 (rappel = identifiant entièrement couvert ; fuite au caractère)
# double_triple : moteur seul (ecluse_core)
Ecluse TOTAL 0.0% 0.0% 0.0% 0 0 943
# regional : moteur seul (ecluse_core)
Ecluse TOTAL 0.0% 0.0% 0.0% 0 0 943
# zero_o : moteur seul (ecluse_core)
Ecluse TOTAL 0.0% 0.0% 0.0% 0 0 943
# sans_traits_union : moteur seul (ecluse_core)
Ecluse TOTAL 0.0% 0.0% 0.0% 0 0 943
# sans_ponctuation : Ecluse.redact (chemin du produit)
finess 129/129 iban 262/262 nir 314/314 rpps 166/166 siren 72/72 TOTAL 943/943 (100.0 %)
fuite au caractère : finess 0.0 % iban 0.0 % nir 0.0 % rpps 0.0 % siren 0.0 % TOTAL 0.0 %
# en_lettres : Ecluse.redact (chemin du produit)
finess 129/129 iban 262/262 nir 314/314 rpps 166/166 siren 72/72 TOTAL 943/943 (100.0 %)
fuite au caractère : finess 0.0 % iban 0.0 % nir 0.0 % rpps 0.0 % siren 0.0 % TOTAL 0.0 %
# double_triple : Ecluse.redact (chemin du produit)
finess 129/129 iban 262/262 nir 314/314 rpps 166/166 siren 72/72 TOTAL 943/943 (100.0 %)
fuite au caractère : finess 0.0 % iban 0.0 % nir 0.0 % rpps 0.0 % siren 0.0 % TOTAL 0.0 %
# regional : Ecluse.redact (chemin du produit)
finess 129/129 iban 262/262 nir 314/314 rpps 166/166 siren 72/72 TOTAL 943/943 (100.0 %)
fuite au caractère : finess 0.0 % iban 0.0 % nir 0.0 % rpps 0.0 % siren 0.0 % TOTAL 0.0 %
# zero_o : Ecluse.redact (chemin du produit)
finess 129/129 iban 262/262 nir 314/314 rpps 166/166 siren 72/72 TOTAL 943/943 (100.0 %)
fuite au caractère : finess 0.0 % iban 0.0 % nir 0.0 % rpps 0.0 % siren 0.0 % TOTAL 0.0 %
# sans_traits_union : Ecluse.redact (chemin du produit)
finess 129/129 iban 262/262 nir 314/314 rpps 166/166 siren 72/72 TOTAL 943/943 (100.0 %)
fuite au caractère : finess 0.0 % iban 0.0 % nir 0.0 % rpps 0.0 % siren 0.0 % TOTAL 0.0 %
## témoin mots-nombres (P2-160) : Ecluse.redact, aucune entité annotée
témoin mots-nombres : 0 prédictions sur 300 phrases
## mots-nombres durci (P2-270, P2-275) : Ecluse.redact, aucune entité annotée
mots-nombres durci : 0 prédictions sur 630 phrases
## signalements « nombre dicté non reconnu » à tort (P2-291) : Ecluse.redact (chemin du produit)
signalements à tort, témoin durci (630, graine 42) : 0 signalées à tort, 0 masquées à tort sur 630 phrases ; 49 avertissements « mot voisin »
signalements à tort, témoin neuf (630, graine 43) : 0 signalées à tort, 0 masquées à tort sur 630 phrases ; 41 avertissements « mot voisin »
signalements à tort, témoin d'origine (300, graine 42) : 0 signalées à tort, 0 masquées à tort sur 300 phrases ; 0 avertissements « mot voisin »
## fuite par OCR (P2-264, P2-268) : Ecluse.redact (chemin du produit)
TOTAL nir libelle couverts 120/120 fuite 0.0 %
TOTAL rpps libelle couverts 120/120 fuite 0.0 %
TOTAL iban libelle couverts 120/120 fuite 0.0 %
TOTAL finess libelle couverts 120/120 fuite 0.0 %
TOTAL siren libelle couverts 120/120 fuite 0.0 %
TOTAL nir sans_libelle couverts 120/120 fuite 0.0 %
TOTAL rpps sans_libelle couverts 0/120 fuite 98.8 %
TOTAL iban sans_libelle couverts 120/120 fuite 0.0 %
TOTAL finess sans_libelle couverts 0/120 fuite 100.0 %
TOTAL siren sans_libelle couverts 0/120 fuite 99.1 %
témoin négatif temoin : 0 / 400 documents avec une prédiction (aucun type)
témoin négatif temoin_dur : 2 / 450 documents avec une prédiction (iban 1, telephone 1)
## OCR derrière un libellé, clé fausse (P2-275) : Ecluse.redact (chemin du produit)
TOTAL nir libelle_cle_fausse couverts 120/120 fuite 0.0 %
TOTAL rpps libelle_cle_fausse couverts 120/120 fuite 0.0 %
TOTAL iban libelle_cle_fausse couverts 120/120 fuite 0.0 %
## sonde des gardes (P2-272, P2-278) : Ecluse.redact (chemin du produit)
sonde adresse cle_non_calculable adresse_cp_commune/Lyon : couverts 20/20
sonde adresse cle_non_calculable adresse_cp_commune/Lyon 2 : couverts 20/20
sonde adresse cle_non_calculable adresse_cp_commune/Lyon 3e : couverts 20/20
sonde adresse cle_non_calculable adresse_cp_commune/Marseille 1er : couverts 20/20
sonde adresse cle_non_calculable adresse_cp_commune/Paris : couverts 20/20
sonde adresse cle_non_calculable adresse_cp_commune/Paris 15 : couverts 20/20
sonde adresse cle_non_calculable adresse_cp_commune/Paris 8e : couverts 20/20
sonde finess cle_non_calculable finess_sans_contexte/seul : couverts 40/40
sonde finess cle_non_calculable finess_sans_contexte/suivi_nombre : couverts 40/40
sonde iban fausse iban_cle_fausse/cinq : couverts 40/40
sonde iban fausse iban_cle_fausse/compact : couverts 40/40
sonde iban fausse iban_cle_fausse/corps_ocr5 : couverts 40/40
sonde iban fausse iban_cle_fausse/paires : couverts 40/40
sonde iban fausse iban_cle_fausse/quatre : couverts 40/40
sonde iban fausse iban_cle_fausse/quatre_points : couverts 40/40
sonde iban fausse iban_cle_fausse/rib : couverts 40/40
sonde iban fausse iban_cle_fausse/trois : couverts 0/40 ; non couverts signalés 40/40
sonde iban juste iban_cle_juste/paires : couverts 40/40
sonde iban cle_non_calculable iban_cle_fausse/cle_o : couverts 40/40
sonde nir fausse nir_cle_fausse/compact : couverts 40/40
sonde nir fausse nir_cle_fausse/deux_lettres : couverts 2/2
sonde nir fausse nir_cle_fausse/points : couverts 40/40
sonde nir fausse nir_cle_fausse/standard : couverts 40/40
sonde nir fausse nir_cle_fausse/suivi_nombre : couverts 40/40
sonde nir fausse nir_cle_fausse/une_lettre : couverts 1/1
sonde nir cle_non_calculable nir_cle_fausse/deux_lettres : couverts 38/38
sonde nir cle_non_calculable nir_cle_fausse/une_lettre : couverts 39/39
sonde TOTAL : couverts 820/860 ; non couverts signalés 40/40
## identifiants dictés abîmés (P2-274, P2-278) : Ecluse.redact (chemin du produit)
# mot_perdu
nir n= 1570 masqués= 769 (dont signalés 0) signalés seulement= 797 rien= 4
iban n= 850 masqués= 664 (dont signalés 0) signalés seulement= 186 rien= 0
TOTAL n= 2420 masqués= 1433 (dont signalés 0) signalés seulement= 983 rien= 4
# cle_fausse
nir n= 1570 masqués= 1253 (dont signalés 0) signalés seulement= 317 rien= 0
iban n= 850 masqués= 781 (dont signalés 0) signalés seulement= 69 rien= 0
TOTAL n= 2420 masqués= 2034 (dont signalés 0) signalés seulement= 386 rien= 0
## faux accords par détecteur (P2-279, P2-284) : Ecluse.redact (chemin du produit)
faux accords : témoin durci de P2-268, élargi : 5000 documents, 58 avec au moins une entité
NIR à clé fausse (P2-258) : 14 / 5000 documents (0.280 %, IC 95 % [0.167 ; 0.469] %), 14 entité(s)
IBAN à clé fausse (P2-252) : 13 / 5000 documents (0.260 %, IC 95 % [0.152 ; 0.444] %), 13 entité(s)
autre : rpps : 9 / 5000 documents (0.180 %, IC 95 % [0.095 ; 0.342] %), 9 entité(s)
adresse : 8 / 5000 documents (0.160 %, IC 95 % [0.081 ; 0.315] %), 8 entité(s)
autre : telephone : 6 / 5000 documents (0.120 %, IC 95 % [0.055 ; 0.262] %), 6 entité(s)
OCR (P2-268) : 5 / 5000 documents (0.100 %, IC 95 % [0.043 ; 0.234] %), 5 entité(s)
finess : 2 / 5000 documents (0.040 %, IC 95 % [0.011 ; 0.146] %), 2 entité(s)
IBAN à clé juste par hasard (P2-252 absent, 1 chance sur 97) : 1 / 5000 documents (0.020 %, IC 95 % [0.004 ; 0.113] %), 1 entité(s)
faux accords : mots-nombres durci, élargi : 5600 documents, 0 avec au moins une entité
aucun détecteur : 0 / 5600 documents (IC 95 % [0.000 ; 0.0686] %)
## flou (entités floues) et variantes de casse
# realiste
restaurations non identiques (harmonisation, LIMITES 5.3) : 0
adresse 159 159 100.0% 100.0% 100.0% 100.0% 0.0%
etablissement 400 400 100.0% 100.0% 100.0% 100.0% 0.0%
nom 479 479 16.3% 16.3% 16.3% 100.0% 27.7%
GLOBAL 1677 1677 76.1% 76.1% 76.1% 100.0% 7.5%
entites predites 1677
# adversarial
restaurations non identiques (harmonisation, LIMITES 5.3) : 62
adresse 155 155 100.0% 100.0% 100.0% 100.0% 0.0%
etablissement 114 114 100.0% 100.0% 100.0% 100.0% 0.0%
nom 594 579 73.2% 71.4% 72.3% 98.7% 11.0%
GLOBAL 1082 1067 85.5% 84.3% 84.9% 99.3% 5.3%
entites predites 1067
# temoin
restaurations non identiques (harmonisation, LIMITES 5.3) : 0
entites predites 0
# realiste_minuscules
restaurations non identiques (harmonisation, LIMITES 5.3) : 0
adresse 159 159 100.0% 100.0% 100.0% 100.0% 0.0%
etablissement 400 400 100.0% 100.0% 100.0% 100.0% 0.0%
nom 479 458 12.4% 11.9% 12.2% 97.8% 30.0%
GLOBAL 1677 1656 75.8% 74.8% 75.3% 99.4% 8.1%
entites predites 1656
# adversarial_minuscules
restaurations non identiques (harmonisation, LIMITES 5.3) : 61
adresse 155 155 100.0% 100.0% 100.0% 100.0% 0.0%
etablissement 114 114 100.0% 100.0% 100.0% 100.0% 0.0%
nom 594 560 66.8% 63.0% 64.8% 97.1% 14.1%
GLOBAL 1082 1048 82.3% 79.7% 80.9% 98.4% 6.8%
entites predites 1048
# temoin_minuscules
restaurations non identiques (harmonisation, LIMITES 5.3) : 0
entites predites 0
# realiste_majuscules
restaurations non identiques (harmonisation, LIMITES 5.3) : 0
adresse 159 159 100.0% 100.0% 100.0% 100.0% 0.0%
etablissement 400 331 82.8% 68.5% 75.0% 90.6% 0.0%
nom 479 527 9.9% 10.9% 10.3% 91.1% 30.0%
GLOBAL 1677 1656 67.9% 67.0% 67.4% 95.2% 8.1%
entites predites 1656
# adversarial_majuscules
restaurations non identiques (harmonisation, LIMITES 5.3) : 55
adresse 155 155 100.0% 100.0% 100.0% 100.0% 0.0%
etablissement 114 16 100.0% 14.0% 24.6% 24.6% 0.0%
nom 594 658 25.7% 28.5% 27.0% 89.5% 14.1%
GLOBAL 1082 1048 53.3% 51.7% 52.5% 89.2% 6.8%
entites predites 1048
# temoin_majuscules
restaurations non identiques (harmonisation, LIMITES 5.3) : 0
entites predites 0
# realiste_phrase
restaurations non identiques (harmonisation, LIMITES 5.3) : 0
adresse 159 159 100.0% 100.0% 100.0% 100.0% 0.0%
etablissement 400 400 100.0% 100.0% 100.0% 100.0% 0.0%
nom 479 458 12.4% 11.9% 12.2% 97.8% 30.0%
GLOBAL 1677 1656 75.8% 74.8% 75.3% 99.4% 8.1%
entites predites 1656
# adversarial_phrase
restaurations non identiques (harmonisation, LIMITES 5.3) : 61
adresse 155 155 100.0% 100.0% 100.0% 100.0% 0.0%
etablissement 114 114 100.0% 100.0% 100.0% 100.0% 0.0%
nom 594 546 66.7% 61.3% 63.9% 95.8% 16.8%
GLOBAL 1082 1034 82.4% 78.7% 80.5% 97.7% 8.1%
entites predites 1034
# temoin_phrase
restaurations non identiques (harmonisation, LIMITES 5.3) : 0
entites predites 0
# fauxamis
restaurations non identiques (harmonisation, LIMITES 5.3) : 0
entites predites 0
## quasi-identifiants (ecluse_reid)
# realiste
age 241 241 100.0% 100.0% 100.0% 100.0% 0.0%
lieu 320 320 100.0% 100.0% 100.0% 100.0% 0.0%
profession 170 170 100.0% 100.0% 100.0% 100.0% 0.0%
# adversarial
age 330 330 100.0% 100.0% 100.0% 100.0% 0.0%
lieu 396 396 100.0% 100.0% 100.0% 100.0% 0.0%
profession 183 183 100.0% 100.0% 100.0% 100.0% 0.0%
# temoin
Extractions totales : 0
# temoin_durees
Extractions totales : 53
## quasi-identifiants par Ecluse.redact (P2-175) : patronyme en clair derrière un métier sans civilité
# realiste
QI par Ecluse.redact : /home/claude/ecluse/bench/qi/corpus_qi_realiste.jsonl
documents : 400
patronyme en clair : 0 document(s)
# adversarial
QI par Ecluse.redact : /home/claude/ecluse/bench/qi/corpus_qi_adversarial.jsonl
documents : 400
patronyme en clair : 29 document(s)
## généralisation appliquée
# realiste
documents avec suggestion : 170 (42.5 %)
refus ou exception à l'application : 0
F médian : avant 74.0, après 1er tour 2002.0, à la fin 7116.0
bande après 1er tour : faible=170
bande à la fin : faible=170
arrêt : plus de suggestion=170
# adversarial
documents avec suggestion : 118 (29.5 %)
refus ou exception à l'application : 0
F médian : avant 7.0, après 1er tour 2320.0, à la fin 9042.3
bande après 1er tour : eleve=1, faible=110, moyen=7
bande à la fin : faible=111, moyen=7
arrêt : plus de suggestion=118
# temoin
documents avec suggestion : 0 (0.0 %)
refus ou exception à l'application : 0
F médian : avant n/a, après 1er tour n/a, à la fin n/a
bande après 1er tour :
bande à la fin :
# lieu
bande recalculée : eleve=1, faible=3, moyen=20
QI lieu dans l'évaluation après application : un QI lieu relu=24
F recalculé vs F simulé : F recalculé = F simulé=24
## dossiers (avec Dossier)
# realiste
Cohérence (identités citées ≥ 2 fois dans un dossier, un seul jeton)
nom 28 / 161 17.4 %
Collisions (jeton désignant plusieurs identités dans un dossier) : 0 / 557 jetons 0.0 %
Fausses fusions (jeton couvrant plusieurs identités dans un même document) : 0 / 935 0.0 %
Restaurations non identiques : 0 / 397 documents 0.0 %
Mentions annotées non détectées (exclues) : aucune
# adversarial
Cohérence (identités citées ≥ 2 fois dans un dossier, un seul jeton)
nom 36 / 128 28.1 %
Collisions (jeton désignant plusieurs identités dans un dossier) : 7 / 455 jetons 1.5 %
Fausses fusions (jeton couvrant plusieurs identités dans un même document) : 7 / 606 1.2 %
Restaurations non identiques : 52 / 398 documents 13.1 %
Mentions annotées non détectées (exclues) : aucune
# temoin
Cohérence (identités citées ≥ 2 fois dans un dossier, un seul jeton)
nom 0 / 129 0.0 %
Collisions (jeton désignant plusieurs identités dans un dossier) : 0 / 757 jetons 0.0 %
Fausses fusions (jeton couvrant plusieurs identités dans un même document) : 0 / 757 0.0 %
Restaurations non identiques : 0 / 396 documents 0.0 %
Mentions annotées non détectées (exclues) : aucune
# realiste_minuscules
Cohérence (identités citées ≥ 2 fois dans un dossier, un seul jeton)
nom 30 / 160 18.8 %
Collisions (jeton désignant plusieurs identités dans un dossier) : 0 / 553 jetons 0.0 %
Fausses fusions (jeton couvrant plusieurs identités dans un même document) : 0 / 931 0.0 %
Restaurations non identiques : 0 / 397 documents 0.0 %
Mentions annotées non détectées (exclues) : nom 4
# realiste_majuscules
Cohérence (identités citées ≥ 2 fois dans un dossier, un seul jeton)
nom 8 / 154 5.2 %
Collisions (jeton désignant plusieurs identités dans un dossier) : 0 / 657 jetons 0.0 %
Fausses fusions (jeton couvrant plusieurs identités dans un même document) : 0 / 907 0.0 %
Restaurations non identiques : 0 / 397 documents 0.0 %
Mentions annotées non détectées (exclues) : nom 28
# realiste_mixte
Cohérence (identités citées ≥ 2 fois dans un dossier, un seul jeton)
nom 18 / 161 11.2 %
Collisions (jeton désignant plusieurs identités dans un dossier) : 0 / 628 jetons 0.0 %
Fausses fusions (jeton couvrant plusieurs identités dans un même document) : 0 / 935 0.0 %
Restaurations non identiques : 95 / 397 documents 23.9 %
Mentions annotées non détectées (exclues) : aucune
# adversarial_minuscules
Cohérence (identités citées ≥ 2 fois dans un dossier, un seul jeton)
nom 36 / 128 28.1 %
Collisions (jeton désignant plusieurs identités dans un dossier) : 7 / 445 jetons 1.6 %
Fausses fusions (jeton couvrant plusieurs identités dans un même document) : 7 / 596 1.2 %
Restaurations non identiques : 52 / 398 documents 13.1 %
Mentions annotées non détectées (exclues) : nom 10
# adversarial_mixte
Cohérence (identités citées ≥ 2 fois dans un dossier, un seul jeton)
nom 24 / 128 18.8 %
Collisions (jeton désignant plusieurs identités dans un dossier) : 6 / 480 jetons 1.2 %
Fausses fusions (jeton couvrant plusieurs identités dans un même document) : 6 / 599 1.0 %
Restaurations non identiques : 94 / 398 documents 23.6 %
Mentions annotées non détectées (exclues) : nom 8
# temoin_mixte
Cohérence (identités citées ≥ 2 fois dans un dossier, un seul jeton)
nom 0 / 129 0.0 %
Collisions (jeton désignant plusieurs identités dans un dossier) : 0 / 757 jetons 0.0 %
Fausses fusions (jeton couvrant plusieurs identités dans un même document) : 0 / 757 0.0 %
Restaurations non identiques : 0 / 396 documents 0.0 %
Mentions annotées non détectées (exclues) : aucune
## patronyme seul hors civilité (P2-218) : Ecluse.redact (chemin du produit)
noms hors civilité, patronyme seul : 116 mentions, manquées document par document 0, en session 0
noms hors civilité, plusieurs mots (civilité ou prénom) : 476 mentions, manquées document par document 0, en session 0
tournure=dossier de : 0 / 49 manqués document par document, 0 / 49 en session
tournure=à la demande de : 0 / 19 manqués document par document, 0 / 19 en session
tournure=entretien avec : 0 / 26 manqués document par document, 0 / 26 en session
tournure=sujet : a confirmé : 0 / 22 manqués document par document, 0 / 22 en session
tournures sans nom : 400 documents, 0 entité(s) annotée(s), 141 masqués à tort
tournure=adressé à : 0 / 80 masqués à tort
tournure=dossier de : 40 / 80 masqués à tort
tournure=à la demande de : 21 / 80 masqués à tort
tournure=entretien avec : 40 / 80 masqués à tort
tournure=sujet : a confirmé : 40 / 80 masqués à tort
genre=lieu : 61 / 100 masqués à tort
genre=organisme : 0 / 100 masqués à tort
genre=commun_majuscule : 80 / 100 masqués à tort
genre=commun_minuscule : 0 / 100 masqués à tort
types sur les masquages à tort : nom 141
## liste de patronymes de l'application (P2-243) : Ecluse.redact (chemin du produit)
# patronyme seul en première mention (corpus b, 400 mentions) : détecté / annoté
# b, liste sans_liste
b_debut 66 / 201 32.8 %
b_milieu 130 / 199 65.3 %
# b, liste exacte
b_debut 201 / 201 100.0 %
b_milieu 199 / 199 100.0 %
# b, liste large
b_debut 201 / 201 100.0 %
b_milieu 199 / 199 100.0 %
# b, liste sans
b_debut 66 / 201 32.8 %
b_milieu 130 / 199 65.3 %
# leurres (un mot courant fourni comme nom, document seul dans son dossier)
leurres, liste sans_liste : 0 / 265 documents sans personne avec un nom masqué
leurres, liste exacte : 265 / 265 documents sans personne avec un nom masqué
leurres, liste large : 265 / 265 documents sans personne avec un nom masqué
leurres, liste sans : 0 / 265 documents sans personne avec un nom masqué
# corpus de dossiers réaliste (116 patronymes seuls) : manqués en session
liste exacte : noms hors civilité, patronyme seul : 116 mentions, manquées document par document 0, en session 0
liste large : noms hors civilité, patronyme seul : 116 mentions, manquées document par document 0, en session 0
liste sans : noms hors civilité, patronyme seul : 116 mentions, manquées document par document 0, en session 0
# témoin sans nom de personne (tournures, 400 documents) : liste large de 10 042 noms
témoin, sans liste : 141 / 400 documents sans personne avec un nom masqué
témoin, liste large : 141 / 400 documents sans personne avec un nom masqué
## tournures de personne, témoin élargi (P2-226) : Ecluse.redact (chemin du produit)
tournures de personne : 480 documents, 5 familles, 192 noms annotés, 0 détection(s) hors du mot
famille=roles : 0 / 96 masqués à tort
tournure=dossier de : 0 / 24
tournure=à la demande de : 0 / 24
tournure=entretien avec : 0 / 24
tournure=sujet : a confirmé : 0 / 24
famille=organismes : 44 / 96 masqués à tort
tournure=dossier de : 11 / 24
tournure=à la demande de : 11 / 24
tournure=entretien avec : 11 / 24
tournure=sujet : a confirmé : 11 / 24
famille=communs : 96 / 96 masqués à tort
tournure=dossier de : 24 / 24
tournure=à la demande de : 24 / 24
tournure=entretien avec : 24 / 24
tournure=sujet : a confirmé : 24 / 24
famille=patronymes_communes : 96 / 96 masqués, 0 en clair (fuite)
tournure=dossier de : 24 / 24
tournure=à la demande de : 24 / 24
tournure=entretien avec : 24 / 24
tournure=sujet : a confirmé : 24 / 24
famille=patronymes_noms_communs : 96 / 96 masqués, 0 en clair (fuite)
tournure=dossier de : 24 / 24
tournure=à la demande de : 24 / 24
tournure=entretien avec : 24 / 24
tournure=sujet : a confirmé : 24 / 24
types sur les masquages à tort : nom 140
types sur les patronymes masqués : nom 192
## communes moyennes derrière les tournures de personne (P2-238) : Ecluse.redact (chemin du produit)
communes moyennes : 240 documents, 0 entité(s) annotée(s), 235 lieux masqués à tort
tranche=10-30k : 78 / 80 lieux masqués à tort
tranche=30-50k : 80 / 80 lieux masqués à tort
tranche=50-100k : 77 / 80 lieux masqués à tort
tournure=dossier de : 60 / 60 lieux masqués à tort
tournure=à la demande de : 60 / 60 lieux masqués à tort
tournure=entretien avec : 60 / 60 lieux masqués à tort
tournure=sujet : a confirmé : 55 / 60 lieux masqués à tort
tranche_tournure=10-30k / dossier de : 20 / 20 lieux masqués à tort
tranche_tournure=10-30k / à la demande de : 20 / 20 lieux masqués à tort
tranche_tournure=10-30k / entretien avec : 20 / 20 lieux masqués à tort
tranche_tournure=10-30k / sujet : a confirmé : 18 / 20 lieux masqués à tort
tranche_tournure=30-50k / dossier de : 20 / 20 lieux masqués à tort
tranche_tournure=30-50k / à la demande de : 20 / 20 lieux masqués à tort
tranche_tournure=30-50k / entretien avec : 20 / 20 lieux masqués à tort
tranche_tournure=30-50k / sujet : a confirmé : 20 / 20 lieux masqués à tort
tranche_tournure=50-100k / dossier de : 20 / 20 lieux masqués à tort
tranche_tournure=50-100k / à la demande de : 20 / 20 lieux masqués à tort
tranche_tournure=50-100k / entretien avec : 20 / 20 lieux masqués à tort
tranche_tournure=50-100k / sujet : a confirmé : 17 / 20 lieux masqués à tort
## prénom + verbe conjugué (P2-240) : Ecluse.redact (chemin du produit)
prénom + verbe : 1280 phrases, 810 verbes masqués, 0 prénoms en clair (fuite)
famille=courants : 0 / 400 verbes masqués, 0 prénoms en clair
famille=reserve : 180 / 200 verbes masqués, 0 prénoms en clair
famille=reserve2 : 630 / 680 verbes masqués, 0 prénoms en clair
## pathologies
# indices
indices : TP 397, FP 0, FN 0 ; précision 100.0 %, rappel 100.0 % ; catégorie juste 96.7 %
FP indices : {}
témoin : 0 faux positifs {}
# variantes
indices : TP 300, FP 0, FN 0 ; précision 100.0 %, rappel 100.0 % ; catégorie juste 100.0 %
FP indices : {}
témoin : 0 faux positifs {}
# formes_libres
TOTAL TP 120, FN 0, FP 210 ; précision 36.4 %, rappel 100.0 %
TOTAL TP 120, FN 0, FP 0 ; précision 100.0 %, rappel 100.0 %
# maladies rares masquées (P2-143)
corpus indices : maladies rares annotées 51, masquées avant 0, après 51 ; pathologies fréquentes masquées 13 ; masquages hors annotation 13 {mucoviscidose: 12, drépanocytose: 1}
corpus temoin : maladies rares annotées 0, masquées avant 0, après 0 ; pathologies fréquentes masquées 0 ; masquages hors annotation 0
échantillon Orphanet (300 mentions, graine 42) : rattachées masquées 276 / 300 ; niées ou générales masquées 0 / 300
## témoin nombres à cinq chiffres (P2-167) : Ecluse.redact (chemin du produit), aucune adresse annotée
témoin cinq chiffres : 400 phrases, 74 prédiction(s) d'adresse par Ecluse.redact (chemin du produit)
voie : détecteur seul 49, texte d'ombre 25, les deux 0 (phrases avec prédiction)
casse=ordinaire : 49 / 244 phrases avec une adresse
casse=phrase : 25 / 156 phrases avec une adresse
famille=montant : 0 / 132 phrases avec une adresse
famille=quantite : 42 / 136 phrases avec une adresse
famille=reference : 32 / 132 phrases avec une adresse
position=debut : 66 / 200 phrases avec une adresse
position=milieu : 8 / 200 phrases avec une adresse
suffixe=majuscule : 49 / 88 phrases avec une adresse
suffixe=minuscule : 25 / 180 phrases avec une adresse
suffixe=rien : 0 / 132 phrases avec une adresse
## témoin déterminant après cinq chiffres (P2-187) : Ecluse.redact (chemin du produit), aucune adresse annotée
témoin cinq chiffres : 400 phrases, 220 prédiction(s) d'adresse par Ecluse.redact (chemin du produit)
voie : détecteur seul 194, texte d'ombre 1, les deux 25 (phrases avec prédiction)
casse=capitales : 107 / 200 phrases avec une adresse
casse=ordinaire : 113 / 200 phrases avec une adresse
famille=quantite : 103 / 208 phrases avec une adresse
famille=reference : 117 / 192 phrases avec une adresse
position=debut : 196 / 200 phrases avec une adresse
position=milieu : 24 / 200 phrases avec une adresse
suffixe=l : 52 / 100 phrases avec une adresse
suffixe=la : 56 / 100 phrases avec une adresse
suffixe=le : 58 / 100 phrases avec une adresse
suffixe=les : 54 / 100 phrases avec une adresse
## code postal en tête (P2-177) : Ecluse.redact (chemin du produit), adresses à ne pas perdre
code postal en tête : 432 adresses, 0 laissée(s) en clair par Ecluse.redact (chemin du produit)
casse=minuscules : 0 / 216 en clair
casse=ordinaire : 0 / 216 en clair
position=apres_phrase : 0 / 144 en clair
position=debut_ligne : 0 / 144 en clair
position=debut_texte : 0 / 144 en clair
suite=ligne : 0 / 108 en clair
suite=minuscule : 0 / 108 en clair
suite=ponctuation : 0 / 108 en clair
suite=rien : 0 / 108 en clair
règle candidate « nom suivi d'un mot en minuscules » (simulée dans le banc, absente de lib/) :
témoin sans adresse : 66 prédiction(s) à tort écartée(s) sur 74 (en tête : 66 sur 66)
adresses annotées : 108 perdue(s) sur 432 (partiraient en clair)
casse=minuscules : 54 / 216 perdue(s)
casse=ordinaire : 54 / 216 perdue(s)
position=apres_phrase : 36 / 144 perdue(s)
position=debut_ligne : 36 / 144 perdue(s)
position=debut_texte : 36 / 144 perdue(s)
suite=minuscule : 108 / 108 perdue(s)
## communes : nom en partie en clair après CEDEX (P2-178, P2-180) : Ecluse.redact (chemin du produit)
cedex commune longue : 139500 adresses, 7 avec au moins un caractère en clair, 0 refus (Ecluse.redact)
ecriture=libelle : 1 / 34875 en défaut, fuite au caractère 0.0 % (19 / 792263) ; commune 1, mot CEDEX 1, numéro 1
ecriture=postale : 0 / 34875 en défaut, fuite au caractère 0.0 % (0 / 766136) ; commune 0, mot CEDEX 0, numéro 0
ecriture=libelle_espaces : 6 / 34875 en défaut, fuite au caractère 0.0 % (79 / 767096) ; commune 6, mot CEDEX 5, numéro 6
ecriture=capitales_tirets : 0 / 34875 en défaut, fuite au caractère 0.0 % (0 / 792263) ; commune 0, mot CEDEX 0, numéro 0
## commune suivie de mots ordinaires (P2-181) : Ecluse.redact (chemin du produit), suite à ne pas masquer
commune suivie : 480 documents, 308 à la suite masquée en partie, 3739 / 6659 caractères de suite masqués (56.1 %), 0 adresse(s) en partie en clair, 0 refus (Ecluse.redact)
famille=capitales : 152 / 160 documents à la suite masquée, 1797 / 2497 caractères ; 0 adresse(s) en clair
famille=liaison : 11 / 160 documents à la suite masquée, 44 / 1808 caractères ; 0 adresse(s) en clair
famille=majuscule : 145 / 160 documents à la suite masquée, 1898 / 2354 caractères ; 0 adresse(s) en clair
ecriture=libelle : 165 / 240 documents à la suite masquée, 2142 / 3294 caractères ; 0 adresse(s) en clair
ecriture=postale : 143 / 240 documents à la suite masquée, 1597 / 3365 caractères ; 0 adresse(s) en clair
## communes en capitales : nom en partie en clair après CEDEX (P2-183, P2-185) : Ecluse.redact (chemin du produit)
cedex commune longue : 139500 adresses, 0 avec au moins un caractère en clair, 0 refus (Ecluse.redact)
cedex=CEDEX n : 0 / 139500 en défaut, fuite au caractère 0.0 % (0 / 3117758) ; commune 0, mot CEDEX 0, numéro 0
## communes en capitales sans CEDEX : nom en partie en clair (P2-200) : Ecluse.redact (chemin du produit)
cedex commune longue : 139500 adresses, 57 avec au moins un caractère en clair, 0 refus (Ecluse.redact)
cedex=sans : 57 / 139500 en défaut, fuite au caractère 0.0 % (921 / 2280758) ; commune 57, mot CEDEX 0, numéro 0
cause=autre : 57 adresse(s) au nom de commune en partie en clair
## témoin mot neutre devant CEDEX (P2-200) : Ecluse.redact (chemin du produit), aucune adresse annotée
témoin cinq chiffres : 400 phrases, 113 prédiction(s) d'adresse par Ecluse.redact (chemin du produit)
voie : détecteur seul 113, texte d'ombre 0, les deux 0 (phrases avec prédiction)
casse=capitales : 113 / 200 phrases avec une adresse
casse=ordinaire : 0 / 200 phrases avec une adresse
famille=quantite : 64 / 204 phrases avec une adresse
famille=reference : 49 / 196 phrases avec une adresse
position=debut : 100 / 200 phrases avec une adresse
position=milieu : 13 / 200 phrases avec une adresse
suffixe=mot : 38 / 136 phrases avec une adresse
suffixe=parenthese : 37 / 132 phrases avec une adresse
suffixe=tiret : 38 / 132 phrases avec une adresse
## communes en capitales sans CEDEX : formes et règles candidates (P2-206) : Ecluse.redact (chemin du produit), règles simulées hors lib/
sans CEDEX : 57 adresses en partie en clair sur 139500, par forme de commune (Ecluse.redact)
forme A : 0 adresse(s), 0 commune(s) (plus de quatre mots) ; exemples :
forme B : 57 adresse(s), 15 commune(s) (mot neutre en tête) ; exemples : SON ; VERS ; SOUS PARSAT
forme C : 0 adresse(s), 0 commune(s) (parenthèse, tiret isolé ou blancs multiples) ; exemples :
forme D : 0 adresse(s), 0 commune(s) (déterminant puis mot neutre) ; exemples :
forme E : 0 adresse(s), 0 commune(s) (mot-clé d'établissement dans le nom) ; exemples :
forme autre : 0 adresse(s), 0 commune(s) (aucune des cinq formes)
balayage sans CEDEX : 57 adresses en partie en clair sur 139500 avec Ecluse.redact seul (règles simulées, hors lib/)
règle=exact_prefixe : 57 → 0 en partie en clair (formes A à D) ; par forme : B 57 → 0
règle=exact_ligne : 57 → 0 en partie en clair (formes A à D) ; par forme : B 57 → 0
règle=fin_de_ligne : 57 → 57 en partie en clair (formes A à D) ; par forme : B 57 → 57
forme E : 0 adresses, non simulable (autre détecteur, EtablissementDetector) ; la même pour toute règle
# coût sur le témoin commune suivie (P2-181) : règle appliquée à toute ligne, puis aux seuls textes en capitales
commune suivie, règles candidates (toute ligne, sans condition de casse) : 480 documents, 3739 / 6659 caractères de suite masqués avec Ecluse.redact seul (308 documents), 0 adresse(s) en partie en clair
règle=exact_prefixe : 3739 / 6659 caractères de suite masqués (+0), 308 documents (+0), 0 adresse(s) en partie en clair
règle=exact_ligne : 3739 / 6659 caractères de suite masqués (+0), 308 documents (+0), 0 adresse(s) en partie en clair
règle=fin_de_ligne : 4808 / 6659 caractères de suite masqués (+1069), 363 documents (+55), 0 adresse(s) en partie en clair
commune suivie, règles candidates (texte sans aucune minuscule seulement) : 480 documents, 5376 / 6659 caractères de suite masqués avec Ecluse.redact seul (462 documents), 0 adresse(s) en partie en clair
règle=exact_prefixe : 5376 / 6659 caractères de suite masqués (+0), 462 documents (+0), 0 adresse(s) en partie en clair
règle=exact_ligne : 5376 / 6659 caractères de suite masqués (+0), 462 documents (+0), 0 adresse(s) en partie en clair
règle=fin_de_ligne : 6631 / 6659 caractères de suite masqués (+1255), 476 documents (+14), 0 adresse(s) en partie en clair
# coût sur les témoins sans adresse annotée : noms de communes de forme neutre (P2-206), puis témoins P2-167 et P2-187
# témoin commune neutre (P2-206)
témoin sans adresse annotée, règles candidates : 400 phrases, 110 avec une adresse prédite par Ecluse.redact, aucune adresse annotée
casse=capitales : 8 / 200 phrases à adresse prédite avec Ecluse.redact seul ; exact_prefixe +192 ; exact_ligne +97 ; fin_de_ligne +0
casse=ordinaire : 102 / 200 phrases à adresse prédite avec Ecluse.redact seul ; exact_prefixe +0 ; exact_ligne +0 ; fin_de_ligne +0
# témoin cinq_chiffres (P2-167, P2-187)
témoin sans adresse annotée, règles candidates : 400 phrases, 74 avec une adresse prédite par Ecluse.redact, aucune adresse annotée
casse=ordinaire : 49 / 244 phrases à adresse prédite avec Ecluse.redact seul ; exact_prefixe +0 ; exact_ligne +0 ; fin_de_ligne +0
casse=phrase : 25 / 156 phrases à adresse prédite avec Ecluse.redact seul ; exact_prefixe +0 ; exact_ligne +0 ; fin_de_ligne +0
# témoin determinant (P2-167, P2-187)
témoin sans adresse annotée, règles candidates : 400 phrases, 220 avec une adresse prédite par Ecluse.redact, aucune adresse annotée
casse=capitales : 107 / 200 phrases à adresse prédite avec Ecluse.redact seul ; exact_prefixe +1 ; exact_ligne +0 ; fin_de_ligne +96
casse=ordinaire : 113 / 200 phrases à adresse prédite avec Ecluse.redact seul ; exact_prefixe +0 ; exact_ligne +0 ; fin_de_ligne +0
## commune à mot de voie (P2-213) : Ecluse.redact (chemin du produit), adresses en partie en clair
commune à mot de voie : 3744 documents, 52 communes, 22 document(s) à adresse en partie en clair (4 commune(s)), 0 refus (Ecluse.redact)
casse=ordinaire : 22 / 2496 en défaut
casse=capitales : 0 / 1248 en défaut
ecriture=postale : 12 / 1248 en défaut
ecriture=libelle : 0 / 624 en défaut
ecriture=libelle_espaces : 10 / 624 en défaut
ecriture=capitales_tirets : 0 / 1248 en défaut
cedex=avec : 0 / 1872 en défaut
cedex=sans : 22 / 1872 en défaut
suite=sans : 8 / 1248 en défaut
suite=mot : 8 / 1248 en défaut
suite=adresse : 6 / 1248 en défaut
voie=sans : 7 / 1872 en défaut
voie=avec : 15 / 1872 en défaut
mot de voie=AVE : 0 / 72 en défaut
mot de voie=CHAUSSEE : 0 / 1080 en défaut
mot de voie=CHEMIN : 14 / 504 en défaut
mot de voie=CLOS : 0 / 216 en défaut
mot de voie=COURS : 0 / 792 en défaut
mot de voie=HAMEAU : 0 / 72 en défaut
mot de voie=PASSAGE : 0 / 144 en défaut
mot de voie=PLACE : 4 / 216 en défaut
mot de voie=RUE : 0 / 504 en défaut
mot de voie=RUELLE : 4 / 144 en défaut
en clair : vraie voie 0, code postal 0, commune 22, seconde adresse 0
début en clair (code postal ou premier mot de la commune) : 0 document(s) ; fin du nom seule en clair : 22
ligne « code postal + mot » masquée (en trop, pas une fuite) : 1248 / 1248
## communes en capitales hors référentiel : « ST », séparateurs collés, fautes (P2-244) : Ecluse.redact (chemin du produit), règles simulées hors lib/
écritures hors référentiel : 1348 adresses, 261 communes des formes A, C et D, tout en capitales, sans CEDEX ; adresses en partie en clair (Ecluse.redact + règle simulée, hors lib/ ; distance 1 pour un nom d'au moins 8 lettres)
# table complete (32587 noms)
variante=reference : 261 adresses, Ecluse.redact seul 0 ; exact 0 ; normalise 0 ; distance1 0
variante=accents : 80 adresses, Ecluse.redact seul 0 ; exact 0 ; normalise 0 ; distance1 0
variante=st : 170 adresses, Ecluse.redact seul 0 ; exact 0 ; normalise 0 ; distance1 0
variante=apostrophe_collee : 69 adresses, Ecluse.redact seul 0 ; exact 0 ; normalise 0 ; distance1 0
variante=tiret_colle : 246 adresses, Ecluse.redact seul 0 ; exact 0 ; normalise 0 ; distance1 0
variante=lettre_fautive : 261 adresses, Ecluse.redact seul 143 ; exact 143 ; normalise 143 ; distance1 0
variante=lettre_omise : 261 adresses, Ecluse.redact seul 141 ; exact 141 ; normalise 141 ; distance1 0
écritures hors référentiel (cinq variantes) : 1007 adresses, Ecluse.redact seul 284 ; exact 284 ; normalise 284 ; distance1 0
# table reduite (261 noms)
variante=reference : 261 adresses, Ecluse.redact seul 0 ; exact 0 ; normalise 0 ; distance1 0
variante=accents : 80 adresses, Ecluse.redact seul 0 ; exact 0 ; normalise 0 ; distance1 0
variante=st : 170 adresses, Ecluse.redact seul 0 ; exact 0 ; normalise 0 ; distance1 0
variante=apostrophe_collee : 69 adresses, Ecluse.redact seul 0 ; exact 0 ; normalise 0 ; distance1 0
variante=tiret_colle : 246 adresses, Ecluse.redact seul 0 ; exact 0 ; normalise 0 ; distance1 0
variante=lettre_fautive : 261 adresses, Ecluse.redact seul 143 ; exact 143 ; normalise 143 ; distance1 0
variante=lettre_omise : 261 adresses, Ecluse.redact seul 141 ; exact 141 ; normalise 141 ; distance1 0
écritures hors référentiel (cinq variantes) : 1007 adresses, Ecluse.redact seul 284 ; exact 284 ; normalise 284 ; distance1 0
## courriers en capitales (P2-210) : Ecluse.redact (chemin du produit), masquage en trop et adresses annotées
courriers : 400 courriers, 3185 lignes, 970 adresses annotées, 0 courrier(s) à adresse en partie en clair (Ecluse.redact)
masquage en trop : 0 courriers / 400, 0 lignes / 3185
famille=reference : 0 / 543 lignes masquées en trop
famille=montant : 0 / 633 lignes masquées en trop
famille=quantite : 0 / 469 lignes masquées en trop
famille=texte : 0 / 570 lignes masquées en trop
famille=adresse : 0 / 837 lignes masquées en trop
famille=montant_adresse : 0 / 133 lignes masquées en trop
types en trop : aucun
## SIREN masqués comme FINESS (P2-223) : Ecluse.redact (chemin du produit)
SIREN masqués comme FINESS : corpus v3 entier 0 / 42 nombres à clé valide non annotés, témoin SIREN 83 / 400, SIREN voisins du pendant FINESS 50 / 100
vrais FINESS en clair sans option : corpus v3 0 / 129, pendant FINESS 0 / 400
témoin libelle=sans_mot : 83 / 100 masqués comme FINESS
témoin libelle=siren_apres : 0 / 100 masqués comme FINESS
témoin libelle=siren_immediat : 0 / 100 masqués comme FINESS
témoin libelle=siren_phrase : 0 / 100 masqués comme FINESS
témoin ecriture=compact : 33 / 200 masqués comme FINESS
témoin ecriture=groupe : 50 / 200 masqués comme FINESS
option=libelle_immediat : SIREN masqués v3 0 / 42, témoin 83 / 400, voisins 24 / 100 ; vrais FINESS perdus en plus (en clair) v3 0 / 129, pendant 0 / 400
option=libelle_40 : SIREN masqués v3 0 / 42, témoin 83 / 400, voisins 24 / 100 ; vrais FINESS perdus en plus (en clair) v3 0 / 129, pendant 26 / 400
option=libelle_40_sans_mot_finess : SIREN masqués v3 0 / 42, témoin 83 / 400, voisins 50 / 100 ; vrais FINESS perdus en plus (en clair) v3 0 / 129, pendant 0 / 400
option=contexte_exige : SIREN masqués v3 0 / 42, témoin 0 / 400, voisins 50 / 100 ; vrais FINESS perdus en plus (en clair) v3 43 / 129, pendant 100 / 400
option=prefixe : SIREN masqués v3 0 / 42, témoin 81 / 400, voisins 50 / 100 ; vrais FINESS perdus en plus (en clair) v3 0 / 129, pendant 0 / 400
témoin : SIREN sous une détection de n'importe quel type 400 / 400 (le reste est lu comme FINESS ou comme un autre type, p. ex. une plaque après « immatriculation »)
option=luhn : SIREN du témoin valides à la clé du FINESS 400 / 400 : aucune distinction possible
## mots neutres, un mot à la fois (P2-211) : Ecluse.redact (chemin du produit), nombres masqués en adresse
mots neutres : 78 mots, 31200 phrases, 218 nombre(s) masqué(s) en adresse, 0 sous un autre type, 4 mot(s) touché(s) (Ecluse.redact)
casse=capitales : 218 / 15600 nombres masqués en adresse
casse=ordinaire : 0 / 15600 nombres masqués en adresse
forme=accentuee : 218 / 30200 nombres masqués en adresse
forme=sans_accent : 0 / 1000 nombres masqués en adresse
position=debut : 136 / 15932 nombres masqués en adresse
position=milieu : 82 / 15268 nombres masqués en adresse
suite=rien : 0 / 10608 nombres masqués en adresse
suite=neutre : 0 / 10316 nombres masqués en adresse
suite=nom : 218 / 10276 nombres masqués en adresse
majuscules=capitales : 218 / 15600 nombres masqués en adresse
majuscules=phrase : 0 / 7800 nombres masqués en adresse
majuscules=mixte : 0 / 7800 nombres masqués en adresse
mot=actes : capitales 0 / 200, ordinaire 0 / 200
mot=agents : capitales 0 / 200, ordinaire 0 / 200
mot=ans : capitales 0 / 200, ordinaire 0 / 200
mot=appels : capitales 0 / 200, ordinaire 0 / 200
mot=au : capitales 0 / 200, ordinaire 0 / 200
mot=aux : capitales 0 / 200, ordinaire 0 / 200
mot=avec : capitales 0 / 200, ordinaire 0 / 200
mot=ce : capitales 0 / 200, ordinaire 0 / 200
mot=centimes : capitales 0 / 200, ordinaire 0 / 200
mot=ces : capitales 0 / 200, ordinaire 0 / 200
mot=cet : capitales 0 / 200, ordinaire 0 / 200
mot=cette : capitales 0 / 200, ordinaire 0 / 200
mot=chez : capitales 0 / 200, ordinaire 0 / 200
mot=cl : capitales 0 / 200, ordinaire 0 / 200
mot=cm : capitales 0 / 200, ordinaire 0 / 200
mot=d : capitales 0 / 200, ordinaire 0 / 200
mot=dans : capitales 0 / 200, ordinaire 0 / 200
mot=de : capitales 0 / 200, ordinaire 0 / 200
mot=des : capitales 0 / 200, ordinaire 0 / 200
mot=dl : capitales 0 / 200, ordinaire 0 / 200
mot=dossier : capitales 0 / 200, ordinaire 0 / 200
mot=dossiers : capitales 0 / 200, ordinaire 0 / 200
mot=du : capitales 0 / 200, ordinaire 0 / 200
mot=en : capitales 0 / 200, ordinaire 0 / 200
mot=est : capitales 0 / 200, ordinaire 0 / 200
mot=et : capitales 0 / 200, ordinaire 0 / 200
mot=eur : capitales 0 / 200, ordinaire 0 / 200
mot=euro : capitales 0 / 200, ordinaire 0 / 200
mot=euros : capitales 0 / 200, ordinaire 0 / 200
mot=habitants : capitales 0 / 200, ordinaire 0 / 200
mot=heures : capitales 0 / 200, ordinaire 0 / 200
mot=iu : capitales 0 / 200, ordinaire 0 / 200
mot=jours : capitales 0 / 200, ordinaire 0 / 200
mot=kcal : capitales 0 / 200, ordinaire 0 / 200
mot=kg : capitales 0 / 200, ordinaire 0 / 200
mot=km : capitales 0 / 200, ordinaire 0 / 200
mot=l : capitales 51 / 200, ordinaire 0 / 200
mot=la : capitales 57 / 200, ordinaire 0 / 200
mot=le : capitales 56 / 200, ordinaire 0 / 200
mot=les : capitales 54 / 200, ordinaire 0 / 200
mot=leur : capitales 0 / 200, ordinaire 0 / 200
mot=leurs : capitales 0 / 200, ordinaire 0 / 200
mot=lits : capitales 0 / 200, ordinaire 0 / 200
mot=mcg : capitales 0 / 200, ordinaire 0 / 200
mot=meq : capitales 0 / 200, ordinaire 0 / 200
mot=mg : capitales 0 / 200, ordinaire 0 / 200
mot=minutes : capitales 0 / 200, ordinaire 0 / 200
mot=ml : capitales 0 / 200, ordinaire 0 / 200
mot=mm : capitales 0 / 200, ordinaire 0 / 200
mot=mmol : capitales 0 / 200, ordinaire 0 / 200
mot=mois : capitales 0 / 200, ordinaire 0 / 200
mot=mol : capitales 0 / 200, ordinaire 0 / 200
mot=ng : capitales 0 / 200, ordinaire 0 / 200
mot=numéro : capitales 0 / 100, ordinaire 0 / 100 ; sans accent : capitales 0 / 100, ordinaire 0 / 100
mot=numéros : capitales 0 / 100, ordinaire 0 / 100 ; sans accent : capitales 0 / 100, ordinaire 0 / 100
mot=ou : capitales 0 / 200, ordinaire 0 / 200
mot=par : capitales 0 / 200, ordinaire 0 / 200
mot=patients : capitales 0 / 200, ordinaire 0 / 200
mot=personnes : capitales 0 / 200, ordinaire 0 / 200
mot=pg : capitales 0 / 200, ordinaire 0 / 200
mot=places : capitales 0 / 200, ordinaire 0 / 200
mot=pour : capitales 0 / 200, ordinaire 0 / 200
mot=que : capitales 0 / 200, ordinaire 0 / 200
mot=qui : capitales 0 / 200, ordinaire 0 / 200
mot=résidents : capitales 0 / 100, ordinaire 0 / 100 ; sans accent : capitales 0 / 100, ordinaire 0 / 100
mot=sa : capitales 0 / 200, ordinaire 0 / 200
mot=salariés : capitales 0 / 100, ordinaire 0 / 100 ; sans accent : capitales 0 / 100, ordinaire 0 / 100
mot=sans : capitales 0 / 200, ordinaire 0 / 200
mot=ses : capitales 0 / 200, ordinaire 0 / 200
mot=son : capitales 0 / 200, ordinaire 0 / 200
mot=sont : capitales 0 / 200, ordinaire 0 / 200
mot=sous : capitales 0 / 200, ordinaire 0 / 200
mot=sur : capitales 0 / 200, ordinaire 0 / 200
mot=ui : capitales 0 / 200, ordinaire 0 / 200
mot=un : capitales 0 / 200, ordinaire 0 / 200
mot=une : capitales 0 / 200, ordinaire 0 / 200
mot=vers : capitales 0 / 200, ordinaire 0 / 200
mot=à : capitales 0 / 100, ordinaire 0 / 100 ; sans accent : capitales 0 / 100, ordinaire 0 / 100
types sur le nombre : adresse 218
## identifiant suivi d'un nombre (P2-174) : Ecluse.redact (chemin du produit)
identifiant suivi : 4800 documents, 1 identifiant(s) non couvert(s), 42 type(s) faux, 42 suite(s) avalée(s), 42 document(s) en défaut
type_id=finess : 41 / 1200 en défaut, 1 non couvert(s)
type_id=iban : 0 / 1200 en défaut, 0 non couvert(s)
type_id=nir : 0 / 1200 en défaut, 0 non couvert(s)
type_id=rpps : 1 / 1200 en défaut, 0 non couvert(s)
separateur=espace : 24 / 1600 en défaut, 1 non couvert(s)
separateur=ligne : 18 / 1600 en défaut, 0 non couvert(s)
separateur=virgule : 0 / 1600 en défaut, 0 non couvert(s)
défaut : finess lu « rpps », age, espace : 16
défaut : finess lu « rpps », age, ligne : 11
défaut : finess lu « rpps », date_lettres, espace : 7
défaut : finess lu « rpps », date_lettres, ligne : 6
défaut : finess lu « rpps », nombre, espace : 1
défaut : rpps lu « nir », nombre, ligne : 1
## identifiant derrière un libellé fort (P2-194) : Ecluse.redact (chemin du produit)
libellé fort : 2000 identifiants positifs, 0 en clair, 0 au type faux ; 1000 documents témoins, 2 masqués à tort (2 prédiction(s))
variante=cle_juste : 0 / 300 en clair, 0 au type faux
variante=cle_fausse : 0 / 300 en clair, 0 au type faux
variante=ocr_zero : 0 / 300 en clair, 0 au type faux
variante=ocr_un : 0 / 300 en clair, 0 au type faux
variante=ligne_vide : 0 / 300 en clair, 0 au type faux
variante=ocr_et_ligne_vide : 0 / 300 en clair, 0 au type faux
variante=cle_fausse_sans_libelle : 0 / 200 en clair, 0 au type faux
libellé=NIR : 0 / 300 en clair, 0 au type faux
libellé=N° de sécurité sociale : 0 / 300 en clair, 0 au type faux
libellé=numéro SS : 0 / 300 en clair, 0 au type faux
libellé=IBAN : 0 / 300 en clair, 0 au type faux
libellé=RPPS : 0 / 300 en clair, 0 au type faux
libellé=ADELI : 0 / 300 en clair, 0 au type faux
libellé=sans libellé : 0 / 200 en clair, 0 au type faux
NIR x cle_juste : 0 / 50 en clair, 0 au type faux
NIR x cle_fausse : 0 / 50 en clair, 0 au type faux
NIR x ocr_zero : 0 / 50 en clair, 0 au type faux
NIR x ocr_un : 0 / 50 en clair, 0 au type faux
NIR x ligne_vide : 0 / 50 en clair, 0 au type faux
NIR x ocr_et_ligne_vide : 0 / 50 en clair, 0 au type faux
N° de sécurité sociale x cle_juste : 0 / 50 en clair, 0 au type faux
N° de sécurité sociale x cle_fausse : 0 / 50 en clair, 0 au type faux
N° de sécurité sociale x ocr_zero : 0 / 50 en clair, 0 au type faux
N° de sécurité sociale x ocr_un : 0 / 50 en clair, 0 au type faux
N° de sécurité sociale x ligne_vide : 0 / 50 en clair, 0 au type faux
N° de sécurité sociale x ocr_et_ligne_vide : 0 / 50 en clair, 0 au type faux
numéro SS x cle_juste : 0 / 50 en clair, 0 au type faux
numéro SS x cle_fausse : 0 / 50 en clair, 0 au type faux
numéro SS x ocr_zero : 0 / 50 en clair, 0 au type faux
numéro SS x ocr_un : 0 / 50 en clair, 0 au type faux
numéro SS x ligne_vide : 0 / 50 en clair, 0 au type faux
numéro SS x ocr_et_ligne_vide : 0 / 50 en clair, 0 au type faux
IBAN x cle_juste : 0 / 50 en clair, 0 au type faux
IBAN x cle_fausse : 0 / 50 en clair, 0 au type faux
IBAN x ocr_zero : 0 / 50 en clair, 0 au type faux
IBAN x ocr_un : 0 / 50 en clair, 0 au type faux
IBAN x ligne_vide : 0 / 50 en clair, 0 au type faux
IBAN x ocr_et_ligne_vide : 0 / 50 en clair, 0 au type faux
RPPS x cle_juste : 0 / 50 en clair, 0 au type faux
RPPS x cle_fausse : 0 / 50 en clair, 0 au type faux
RPPS x ocr_zero : 0 / 50 en clair, 0 au type faux
RPPS x ocr_un : 0 / 50 en clair, 0 au type faux
RPPS x ligne_vide : 0 / 50 en clair, 0 au type faux
RPPS x ocr_et_ligne_vide : 0 / 50 en clair, 0 au type faux
ADELI x cle_juste : 0 / 50 en clair, 0 au type faux
ADELI x cle_fausse : 0 / 50 en clair, 0 au type faux
ADELI x ocr_zero : 0 / 50 en clair, 0 au type faux
ADELI x ocr_un : 0 / 50 en clair, 0 au type faux
ADELI x ligne_vide : 0 / 50 en clair, 0 au type faux
ADELI x ocr_et_ligne_vide : 0 / 50 en clair, 0 au type faux
sans libellé x cle_fausse_sans_libelle : 0 / 200 en clair, 0 au type faux
témoin négatif=libelle_seul : 0 / 300 masqués à tort (0 prédiction(s))
témoin négatif=non_communique : 0 / 300 masqués à tort (0 prédiction(s))
témoin négatif=mot_ordinaire : 0 / 300 masqués à tort (0 prédiction(s))
témoin négatif=nombre_sans_libelle : 2 / 100 masqués à tort (2 prédiction(s))
témoin négatif, libellé=NIR : 0 / 150 masqués à tort
témoin négatif, libellé=N° de sécurité sociale : 0 / 150 masqués à tort
témoin négatif, libellé=numéro SS : 0 / 150 masqués à tort
témoin négatif, libellé=IBAN : 0 / 150 masqués à tort
témoin négatif, libellé=RPPS : 1 / 200 masqués à tort
témoin négatif, libellé=ADELI : 1 / 200 masqués à tort
confiance des masquages (chemin : Ecluse.redact) :
confiance positifs : 0.3=1649, 0.6=50, 0.9=50, 0.95=50, 1=201
confiance variante=cle_juste : 0.9=50, 0.95=50, 1=200
confiance variante=cle_fausse : 0.3=250, 0.6=50
confiance variante=ocr_zero : 0.3=300
confiance variante=ocr_un : 0.3=300
confiance variante=ligne_vide : 0.3=300
confiance variante=ocr_et_ligne_vide : 0.3=300
confiance variante=cle_fausse_sans_libelle : 0.3=199, 1=1
confiance détections des négatifs : 0.55=2
avertissement à vérifier : positifs 1699 / 2000, négatifs 1 / 1000
à vérifier variante=cle_juste : 0 / 300
à vérifier variante=cle_fausse : 300 / 300
à vérifier variante=ocr_zero : 300 / 300
à vérifier variante=ocr_un : 300 / 300
à vérifier variante=ligne_vide : 300 / 300
à vérifier variante=ocr_et_ligne_vide : 300 / 300
à vérifier variante=cle_fausse_sans_libelle : 199 / 200
incohérence confiance 0.3 / avertissement : positifs 0, négatifs 1
exception P2-204 (ADELI clé fausse, confiance 0.6, avec avertissement) : positifs 50
## mise en page (P2-153) : textes recoupés aux espaces, largeur 60 puis 90
# realiste largeur 60 : 3 refus
adresse 156 156 100.0% 100.0% 100.0% 100.0% 0.0%
etablissement 397 397 100.0% 100.0% 100.0% 100.0% 0.0%
nom 476 476 16.4% 16.4% 16.4% 100.0% 27.6%
GLOBAL 1662 1646 75.8% 75.1% 75.5% 99.5% 8.2%
entités coupées par une fin de ligne : adresse 95 coupées (95 couvertes, 0 en partie en clair, 0 entièrement en clair, 0 car.) ; etablissement 4 coupées (4 couvertes, 0 en partie en clair, 0 entièrement en clair, 0 car.)
# adversarial largeur 60 : 0 refus
adresse 155 155 100.0% 100.0% 100.0% 100.0% 0.0%
etablissement 114 114 100.0% 100.0% 100.0% 100.0% 0.0%
nom 594 579 73.2% 71.4% 72.3% 98.7% 11.0%
GLOBAL 1082 1067 85.5% 84.3% 84.9% 99.3% 5.3%
entités coupées par une fin de ligne : adresse 106 coupées (106 couvertes, 0 en partie en clair, 0 entièrement en clair, 0 car.) ; etablissement 0 coupées (0 couvertes, 0 en partie en clair, 0 entièrement en clair, 0 car.)
# temoin largeur 60 : 0 refus
entites predites 0
# structurel largeur 60, moteur seul (ecluse_core)
Ecluse nir 100.0% 92.7% 96.2% 291 0 23
Ecluse rpps 95.5% 90.4% 92.9% 150 7 16
Ecluse iban 100.0% 77.9% 87.6% 204 0 58
Ecluse finess 100.0% 100.0% 100.0% 129 0 0
Ecluse TOTAL 99.2% 89.7% 94.2% 846 7 97
# structurel largeur 60, détecteur isolé (appel direct des quatre détecteurs)
finess 129/129 iban 156/262 nir 247/314 rpps 150/166 siren 72/72 TOTAL 754/943 (80.0 %)
# structurel largeur 60, Ecluse.redact (chemin du produit)
finess 129/129 iban 262/262 nir 314/314 rpps 166/166 siren 72/72 TOTAL 943/943 (100.0 %)
# realiste largeur 90 : 0 refus
adresse 159 159 100.0% 100.0% 100.0% 100.0% 0.0%
etablissement 400 400 100.0% 100.0% 100.0% 100.0% 0.0%
nom 479 479 16.3% 16.3% 16.3% 100.0% 27.7%
GLOBAL 1677 1677 76.1% 76.1% 76.1% 100.0% 7.5%
entités coupées par une fin de ligne : adresse 83 coupées (83 couvertes, 0 en partie en clair, 0 entièrement en clair, 0 car.) ; etablissement 44 coupées (44 couvertes, 0 en partie en clair, 0 entièrement en clair, 0 car.)
# adversarial largeur 90 : 0 refus
adresse 155 155 100.0% 100.0% 100.0% 100.0% 0.0%
etablissement 114 114 100.0% 100.0% 100.0% 100.0% 0.0%
nom 594 579 73.2% 71.4% 72.3% 98.7% 11.0%
GLOBAL 1082 1067 85.5% 84.3% 84.9% 99.3% 5.3%
entités coupées par une fin de ligne : adresse 106 coupées (106 couvertes, 0 en partie en clair, 0 entièrement en clair, 0 car.) ; etablissement 0 coupées (0 couvertes, 0 en partie en clair, 0 entièrement en clair, 0 car.)
# temoin largeur 90 : 0 refus
entites predites 0
# structurel largeur 90, moteur seul (ecluse_core)
Ecluse nir 100.0% 100.0% 100.0% 314 0 0
Ecluse rpps 98.2% 100.0% 99.1% 166 3 0
Ecluse iban 100.0% 89.7% 94.6% 235 0 27
Ecluse finess 100.0% 100.0% 100.0% 129 0 0
Ecluse TOTAL 99.7% 97.1% 98.4% 916 3 27
# structurel largeur 90, détecteur isolé (appel direct des quatre détecteurs)
finess 129/129 iban 187/262 nir 269/314 rpps 166/166 siren 72/72 TOTAL 823/943 (87.3 %)
# structurel largeur 90, Ecluse.redact (chemin du produit)
finess 129/129 iban 262/262 nir 314/314 rpps 166/166 siren 72/72 TOTAL 943/943 (100.0 %)
## collage de fin de ligne hors du cœur (P2-166)
../../bench/flou/structurel_l60.jsonl : 1000 doc., 97 coupures chiffre-fin de ligne-chiffre, 96 détections traversant une coupure (iban 58, nir 22, rpps 16) = 96 attendues + 0 à tort, 0 colonnes de 9/11/13 chiffres
../../bench/flou/structurel_l90.jsonl : 1000 doc., 27 coupures chiffre-fin de ligne-chiffre, 27 détections traversant une coupure (iban 27) = 27 attendues + 0 à tort, 0 colonnes de 9/11/13 chiffres
../../bench/flou/corpus_flou_temoin_l60.jsonl : 400 doc., 0 coupures chiffre-fin de ligne-chiffre, 0 détections traversant une coupure (aucune) = 0 attendues + 0 à tort, 0 colonnes de 9/11/13 chiffres
../../bench/flou/corpus_flou_temoin_l90.jsonl : 400 doc., 0 coupures chiffre-fin de ligne-chiffre, 0 détections traversant une coupure (aucune) = 0 attendues + 0 à tort, 0 colonnes de 9/11/13 chiffres
Contrôle : 0 détection(s) traversant une coupure dans le texte non recollé (attendu 0).
cas « Salle 4⏎A2 » : 1 coupure(s), 0 détection(s) traversant une coupure
cas « Vol 12⏎B7 » : 1 coupure(s), 0 détection(s) traversant une coupure
cas « le 3⏎C4 du plan » : 1 coupure(s), 0 détection(s) traversant une coupure
cas « chambres 101⏎102 » : 3 coupure(s), 0 détection(s) traversant une coupure
cas « tableau de chambres » : 7 coupure(s), 0 détection(s) traversant une coupure
colonne de 2 nombres de 9 chiffres (tirage uniforme) : 0 détection(s) traversant une coupure sur 2000 colonnes
colonne de 10 nombres de 9 chiffres (tirage uniforme) : 0 détection(s) traversant une coupure sur 2000 colonnes
colonne de 2 nombres de 11 chiffres (tirage uniforme) : 0 détection(s) traversant une coupure sur 2000 colonnes
colonne de 10 nombres de 11 chiffres (tirage uniforme) : 0 détection(s) traversant une coupure sur 2000 colonnes
colonne de 2 nombres de 13 chiffres (tirage uniforme) : 0 détection(s) traversant une coupure sur 2000 colonnes
colonne de 10 nombres de 13 chiffres (tirage uniforme) : 0 détection(s) traversant une coupure sur 2000 colonnes
```
<!-- controle:fin -->

## Listes d'exclusion des noms : homonymes écartés signalés (P2-310, 27 novembre 2026)

Chemin mesuré : **`Ecluse.redact`** (`packages/ecluse_redact/bin/run_gardes_avertissements.dart`),
pas le moteur seul. Aucun masquage ne change (l'avertissement est ajouté après la
détection, sur le texte et les entités résolues). Seuls les mots qui sont aussi un
patronyme INSEE (236, `homonymes_patronymes.dart`, généré par
`python3 bench/listes_exclusion.py homonymes_dart --ecrire`) sont signalés.

Sonde de P2-308 (`bench/mesure_listes_exclusion.sh`, patronymes en clair
signalés, toutes tournures) :

| Liste | Avant | Après |
|---|---|---|
| `verbes_conjugues` | 0 / 170 | **170 / 170** |
| `statuts` | 0 / 29 | **29 / 29** |
| `mots_voisins_neutres` | 0 / 30 | **30 / 30** |
| `mots_de_role` | 0 / 30 | **30 / 30** |

Les neuf autres listes restent silencieuses (hors fiche). Témoin de patronymes
hors liste (160 documents) : 0 signalé.

Documents avertis sur les témoins propres (seuil d'arrêt : 5 %) :

| Témoin | Documents | Avertis |
|---|---|---|
| mots neutres | 31 200 | 0 |
| commune neutre, neutre cedex, faux amis, réaliste, adversarial | 5 × 400 | 0 |
| v3 (graine 42) | 1 000 | 0 |
| commune suivie | 480 | 0 |
| durci élargi (faux accords OCR) | 5 000 | 0 |
| mots-nombres durci élargi | 5 600 | 0 |
| libellé fort | 3 000 | 0 |
| sonde prénom + verbe (P2-240), casse ordinaire | 1 280 | 0 |
| **même sonde mise en minuscules** | 1 280 | **240** (18,75 %, tous des verbes légitimes qui sont aussi un patronyme) |

Lecture : le bruit est nul sur les témoins du dépôt, qui ne contiennent aucune de
ces tournures ; il est massif sur du texte entièrement en minuscules, où le
prénom suivi d'un verbe de la liste est signalé. Un document ne porte jamais
plus d'un avertissement de ce type (compte et positions).

## Homonymes écartés : neuf autres listes (P2-316, 27 novembre 2026)

Chemin mesuré : `Ecluse.redact` (`bin/run_gardes_avertissements.dart`). Documents avec un
avertissement d'homonyme, `main` → branche : `faux amis` 0 → 0 (38 sans le filtre des
prénoms-noms communs) ; `tournures_sans_nom` 8 → 8 (59 sans le filtre des déterminants,
casse ordinaire) ; `tournures_personne` 33 → 36 ; `adversarial_minuscules` 0 → 10 ;
`dossiers_temoin_minuscules` 0 → 5 ; `transcrit_en_lettres` 0 → 6 ; `realiste_minuscules`,
`realiste_phrase`, `temoin_phrase` 0 → 0. Sonde de P2-308, neuf listes : 107 / 148 en casse
ordinaire, 193 / 316 en minuscules ; tous les cas non signalés sont des déterminants.
Quatre listes de P2-310 : inchangées (607 / 607 en minuscules, 77 / 77 en casse ordinaire).
Aucun masquage ne change ; `etat.sh` conforme au bloc contrôlé.

## Homonymes écartés en texte sans majuscule : chemins « civilité » et « le dossier de » (P2-315, 27 novembre 2026)

Chemin mesuré : **`Ecluse.redact`** (`packages/ecluse_redact/bin/run_gardes_avertissements.dart`),
pas le moteur seul. Aucun masquage ne change : les 77 fichiers `pred*.jsonl` du
tableau de bord sont identiques octet pour octet avant et après
(`bench/equivalence_predictions.sh` : « identiques : 77 ; différents comme prévu : 0 »),
et `controle_etat.py` est conforme. Rejeu complet de `bench/etat.sh` sur `main` (au
commit `37dfe65`, dans un worktree propre) puis sur la branche : mêmes lignes, aucun
`ÉCHEC`.

Sonde de P2-308 (`bash bench/mesure_homonymes_minuscules.sh`, ligne « base »), homonymes
laissés en clair et signalés :

| Texte | Avant | Après |
|---|---|---|
| Entièrement en minuscules (quatre listes) | 364 / 607 | **607 / 607** |
| dont `verbes_conjugues` | 340 / 514 | 514 / 514 |
| dont `statuts` | 14 / 25 | 25 / 25 |
| dont `mots_voisins_neutres` | 6 / 36 | 36 / 36 |
| dont `mots_de_role` | 4 / 32 | 32 / 32 |
| Casse ordinaire | 77 / 77 | 77 / 77 |

Documents avertis sur les témoins propres (seuil d'arrêt : 5 % en casse ordinaire),
mesurés sur les corpus générés par `bench/etat.sh` (100 992 documents au total) :

| Témoin | Documents | Avertis avant | Avertis après |
|---|---|---|---|
| v3 (graine 42) | 1 000 | 0 | 0 |
| mots neutres | 31 200 | 0 | 0 |
| commune neutre, neutre cedex, réaliste, adversarial (casse ordinaire) | 4 × 400 | 0 | 0 |
| commune suivie | 480 | 0 | 0 |
| durci élargi (faux accords OCR), mots-nombres durci élargi | 5 000 + 5 600 | 0 | 0 |
| libellé fort | 3 000 | 0 | 0 |
| sonde prénom + verbe (P2-240), casse ordinaire | 1 280 | 0 | 0 |
| dossiers, variantes minuscules, mixte et phrase | 12 × ≈ 400 | 0 | 0 (113 sur 396 avant d'écarter un mot suivi d'une entité : « le dossier de monsieur pelletan ») |
| **tournures sans nom** (`corpus_tournures_sans_nom`) | 400 | 0 | **8** (2,0 %, tous « contrôle ») |
| tournures de personne (`corpus_tournures_personne`) | 480 | 33 | 33 (inchangé : chemin capitalisé de P2-310) |

Lecture : le coût nouveau est de 8 documents sur 400 du témoin « tournures sans nom »
(« à la demande de contrôle », « le dossier de contrôle » : un nom commun qui est aussi
un verbe et un patronyme), 2,0 %, sous le seuil de 5 %. Les 33 de « tournures de
personne » existaient avant (mots de rôle capitalisés derrière la tournure, P2-310) ;
ce corpus est fait de ces tournures, il n'est pas un témoin de bruit. Les options
`O1` à `O5` de P2-314, qui filtrent le chemin « prénom + mot », jugent désormais aussi
les mots des nouveaux chemins : leurs lignes ne sont plus celles du rapport de P2-314.
Non rejoué : les 200 000 phrases sans personne, la casse « de phrase » (majuscule en
début de phrase seulement), une civilité capitalisée devant un mot en minuscules
(« Madame fait un malaise » : 0 avertissement, limite dans `LIMITES.md`).

## Garde `nir_coupures` : avertissement « à vérifier » (P2-305, 27 novembre 2026)

Chemin mesuré : **`Ecluse.redact`** (`packages/ecluse_redact/bin/run_gardes_avertissements.dart`),
pas le moteur seul. Aucun masquage ne change : les 77 fichiers `pred*.jsonl` du
tableau de bord sont identiques octet pour octet avant et après (rejeu complet de
`bench/etat.sh` sur `main` au commit `9cd7cd2`, puis sur la branche), et le bloc
« Valeurs courantes contrôlées » est inchangé (`controle_etat.py` : conforme).

Sonde de P2-303 (`generate_sonde_gardes_silencieuses.py --n 40 --seed 42`, famille
`nir_coupures`, 40 NIR à clé fausse en groupes de quatre) : signalés **0 / 40 avant,
40 / 40 après** ; 642 caractères sur 720 restent en clair (le passage n'est pas
masqué, il est signalé).

Documents qui portent le nouvel avertissement (« NIR à clé fausse écrit en groupes
inhabituels, non masqué : à vérifier »), sans qu'aucune entité ne le couvre :

| Témoin | Documents avec l'avertissement | dont un NIR annoté |
|---|---|---|
| durci élargi (faux accords OCR, 5 000) | 2 | 0 (deux codes de colis) |
| mots-nombres durci élargi (5 600) | 0 | 0 |
| mots-nombres durci (630, graines 42 et 43) et d'origine (300) | 0 | 0 |
| v3 (1 000, graine 42) | 0 | 0 |
| libellé fort (3 000) | 0 | 0 |

Lecture : le coût est de 2 documents sur 5 000 du témoin durci élargi, deux codes
de colis écrits en groupes de quatre ; il n'y a pas de NIR annoté dans ces
corpus qui soit écrit ainsi, donc rien à gagner non plus sur eux : le bénéfice est
celui de la sonde (40 / 40), pas d'un corpus naturel.

## Candidat écarté devant une date complète : avertissement « à vérifier » (P2-309, 27 novembre 2026)

Chemin mesuré : **`Ecluse.redact`** (`packages/ecluse_redact/bin/run_gardes_avertissements.dart`),
pas le moteur seul. Aucun masquage ne change (`detect` garde son comportement ;
`candidatsEcartesDevantDate` ne fait que comparer avec la garde désactivée). Le
tableau de bord complet (`bench/etat.sh`, 9 min) a été rejoué sur la branche : le
bloc « Valeurs courantes contrôlées » est inchangé (`controle_etat.py` :
conforme), aucune ligne `ÉCHEC`. Les fichiers de prédictions n'ont pas été
comparés octet pour octet à `main` (non rejoué sur `main` dans cette session).

Sonde (identifiants fabriqués, clés calculées, séparateur `/`, date `jj/03/2024`) :

| Type | Textes | Candidats écartés non couverts | Signalés avant | Signalés après |
|---|---|---|---|---|
| NIR (clé ≤ 39) | 156 | 156 | 0 | **156** |
| RPPS (deux derniers chiffres ≤ 39) | 160 | 160 | 0 | **160** |
| FINESS (« 12 345 678 9/03/2024 ») | 400 | 400 | 0 | **400** |
| IBAN (groupes usuels) | 50 | 0 (non constructible) | 0 | 0 |

Documents qui portent l'avertissement « de clé juste suivi d'une date », sans
qu'aucune entité ne le couvre en entier :

| Témoin | Documents | Avec l'avertissement | Dont à tort |
|---|---|---|---|
| durci élargi (faux accords OCR) | 5 000 | 0 | 0 |
| mots-nombres durci élargi | 5 600 | 0 | 0 |
| commune suivie | 480 | 0 | 0 |
| v3 (graine 42) | 1 000 | 0 | 0 |
| libellé fort | 3 000 | 0 | 0 |
| identifiant suivi | 4 800 | 10 (3 NIR, 7 RPPS) | 10 |

Lecture : les 10 documents du témoin « identifiant suivi » ont leur identifiant
réel (RPPS ou FINESS) masqué en entier ; l'avertissement vient d'une lecture
voisine (NIR ou RPPS) du même nombre élargi aux chiffres de la date, que l'entité
réelle ne couvre pas en entier. C'est un avertissement en trop, pas une fuite.
Non rejoué : les 200 000 phrases sans personne.

### Doublons de l'avertissement « suivi d'une date » (P2-312, 27 novembre 2026)

Chemin mesuré : `Ecluse.redact` (ce que reçoit le LLM), témoin « identifiant suivi »
(4 800 documents, graine 42). Un candidat écarté n'est plus signalé quand une entité
**à confiance ≥ 0,9** masque déjà en entier ses chiffres d'identifiant (le candidat
privé de son dernier groupe, qui est le début de la date).

| Mesure | Avant | Après |
|---|---|---|
| Documents du témoin « identifiant suivi » avec l'avertissement | 10 (3 NIR, 7 RPPS) | **2** |
| Sonde de P2-309 (716 textes, NIR, RPPS, FINESS) signalés | 716 / 716 | 716 / 716 |

Les 8 doublons retirés ont une entité couvrante à 0,9 (libellé ou forme confirmés).
Les 2 restants (« Établissement … » + FINESS de Luhn juste sans libellé, confiance 0,5)
**ne sont pas retirés** : la fiche demandait 10 → 0, mais ces deux textes ont la
forme exacte de 16 cas de la sonde RPPS (« Prescripteur 100033000 18/03/2024 » :
un RPPS dont les neuf premiers chiffres sont aussi un FINESS de Luhn juste, masqué à
0,5), où l'avertissement est le seul signe que deux chiffres d'un RPPS restent en
clair. Les retirer rendait ces 16 cas silencieux (716 → 700 signalés). Aucun masquage
ne change. Non rejoué : les 200 000 phrases sans personne.
