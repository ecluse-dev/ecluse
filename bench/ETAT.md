# État des mesures — tableau de bord (P2-130)

Toutes les mesures du dépôt rejouées d'un coup sur `main` au commit
**`d85fb84`** (6 novembre 2026), graine 42 partout, puis rejouées au commit
**`a263a83`** (7 novembre, après P2-136 à P2-141) ; les lignes modifiées le
disent. Commande :

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
| adversarial | 13,9 % (P2-147) | **0 %** (1,9 % avant P2-164) | 0 % | **6,7 %** | | 61 |
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
| adversarial | 7 / 445 (1,6 %) | 7 / 596 (1,2 %) | 52 / 398 (13,1 %) |
| témoin | 0 / 757 | 0 / 757 | 0 / 396 |

Variantes de casse (P2-140, P2-144, P2-145 ; `variantes_casse.py`, `_mixte` =
une casse par document, en rotation dans le dossier) :

| Corpus | Cohérence nom | Noms non détectés (avant P2-144) | Restaurations non identiques |
|---|---:|---:|---:|
| réaliste en minuscules | 30 / 160 | 4 (116) | 0 / 397 |
| réaliste en capitales | 8 / 154 | 28 (104) | 0 / 397 |
| réaliste à casse mixte | 18 / 161 | 0 (88) | 95 / 397⁵ |
| adversarial en minuscules | 36 / 128 | 10 (47) | 52 / 398 |
| adversarial à casse mixte | 24 / 128 | 12 (43) | 94 / 398⁵ |
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
| adversarial, 60 et 90 | 7 et 0 | 13,9 % | 0 % | 0 % | **6,7 %** (inchangé) | 0 |
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
