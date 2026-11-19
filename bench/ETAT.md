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

## Identifiants structurels (corpus v3, 1 000 documents, 778 entités)

| Corpus | Précision | Rappel | F1 | FP | Source |
|---|---:|---:|---:|---:|---|
| v3 d'origine | 94,9 % | 100 % | 97,4 % | 42 (FINESS/SIREN) | = P1-36 |
| v3 sans ponctuation, minuscules | 94,9 % | 100 % | 97,4 % | 42 | = P2-98 |
| v3 nombres en lettres | 0 % | **0 %** | 0 % | 0 | = P2-98 |

## Dictée : identifiants dits en lettres (P2-160)

Corpus v3 (1 000 documents, 778 identifiants) transcrits sans audio par
`bench/generate_corpus_transcrit.py` : les deux variantes d'origine (sorties
**identiques octet pour octet** après P2-160) et quatre variantes de dictée
(`agent/specs/P2-155.md` § 2) : `double_triple` (« double zéro », « triple
neuf », chiffre par chiffre), `regional` (« septante », « huitante », « nonante »,
par groupes), `zero_o` (« o six »), `sans_traits_union` (« quatre vingt treize »,
par groupes). **Aucun détecteur modifié** : c'est le point de départ de la
future tâche de code (défaut d'abord).

Deux chemins, à ne pas confondre. « Rappel » = identifiant entièrement couvert
par une détection quel qu'en soit le type ; « fuite » = part des caractères
d'identifiant (blancs exclus) couverts par aucune détection.

| Variante | **`Ecluse.redact`** (ce que reçoit le LLM) : rappel | fuite au caractère | moteur seul (`ecluse_core`) : rappel |
|---|---:|---:|---:|
| sans ponctuation (chiffres) | 778/778 | 0,0 % | 100 % (42 FP FINESS/SIREN) |
| en lettres (d'origine) | 23/778 (3,0 %) | 97,3 % | 0 % |
| double / triple | 18/778 (2,3 %) | 97,6 % | 0 % |
| septante / huitante / nonante | 32/778 (4,1 %) | 96,9 % | 0 % |
| zéro dit « o » | 25/778 (3,2 %) | 97,2 % | 0 % |
| traits d'union perdus | 34/778 (4,4 %) | 96,9 % | 0 % |

Par type (fuite au caractère, `Ecluse.redact`) : NIR 99,9 à 100 %, RPPS 100 %,
IBAN 99,9 à 100 %, FINESS 68 à 76 % selon la variante. Les rares identifiants
« couverts » sont des FINESS recouverts par une détection de type
**établissement** (vérifié sur la variante d'origine : 23 sur 23) ; aucune
variante n'est lue comme identifiant. **Un identifiant dicté en lettres part donc en clair par
`Ecluse.redact`, quelle que soit la façon de le dicter.**

Témoin « mots-nombres » (`bench/generate_corpus_mots_nombres.py`, 300 phrases
synthétiques sans identifiant, dont 150 avec au moins 6 mots-nombres
consécutifs, aucune entité annotée) : **0 prédiction** par `Ecluse.redact`.
Aujourd'hui sans enjeu (aucun détecteur ne lit de nombre en lettres) ; c'est le
garde-fou du futur GO : une détection à tort sur ce corpus le bloque.

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

Témoins négatifs : **8 documents sur 1 200 masqués** (0 sur `libelle_seul`,
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
