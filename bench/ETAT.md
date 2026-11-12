# État des mesures — tableau de bord (P2-130)

Toutes les mesures du dépôt rejouées d'un coup sur `main` au commit
**`d85fb84`** (6 novembre 2026), graine 42 partout, puis rejouées au commit
**`a263a83`** (7 novembre, après P2-136 à P2-141) ; les lignes modifiées le
disent. Commande :

```bash
bash bench/etat.sh > etat.log 2>&1   # depuis la racine, Dart et Python requis
```

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
| adversarial | 13,9 % (P2-147) | 1,9 % | 0 % | **7,2 %** | | 61 |
| témoin | | | | | **0** | 0 |
| réaliste en minuscules | 30,0 %⁴ | 0 % | 0 % | **8,1 %** | | 0 |
| adversarial en minuscules | 14,1 %⁴ | 1,9 % | 0 % | **7,2 %** | | 61³ |
| témoin en minuscules | | | | | **0** | 0 |
| réaliste en capitales | 30,0 %⁴ | 0 % | 0 % | **8,1 %** | | 0 |
| adversarial en capitales | 14,1 %⁴ | 1,9 % | 0 % | **7,2 %** | | 55 |
| témoin en capitales | | | | | **0** | 0 |
| faux amis prénoms (P2-124) | | | | | **0** | 0 |
| réaliste en casse de phrase (P2-138) | 30,0 %⁴ | 0 % | 0 % | **8,1 %** | | 0 |
| adversarial en casse de phrase (P2-138) | 16,8 %⁴ | 1,9 % | 0 % | **8,6 %** | | 61³ |
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
| adversarial | 13,9 % → **8,3 %** | 7,2 % → **4,4 %** | 61 → 58 |

Noms de l'adversarial hors civilité : 572 → **0** caractère
(`leak_hors_civilite.py`) ; les 8,3 % restants sont la civilité. Réaliste,
témoins, faux amis, variantes de casse et dossiers : identiques à l'option
désactivée. Prose des `.md` du dépôt (`run_prenoms_insee_prose.dart`) :
6 nouvelles détections, toutes de vrais noms, après l'exclusion de « France
Travail » et « Ange Gardien » (P2-150 ; `agent/specs/P2-148.md` § 6).

## Quasi-identifiants (`ecluse_reid`, corpus QI, 400 documents)

| Corpus | âge P / R | lieu P / R | profession P / R | Non couverts (âge / lieu / prof.) |
|---|---|---|---|---|
| réaliste | 100 / 100 % | 88,2 / 100 % | 100 / 100 % | 0 / 0 / 0 % |
| adversarial | 100 / **100 %** (95,5 % avant P2-159) | 92,3 / 100 % | 100 / 96,2 % | **0** (12,7 avant P2-159) / 0 / 2,0 % |
| témoin | 412 extractions à tort, 337 documents sur 400 ; **57 / 57 après P2-136, 0 après P2-142** | | | |

Identique à `bench/README.md` (P2-03b) au commit `d85fb84` ; témoin corrigé
ensuite par P2-136 (durées, communes-mots courants), réaliste et
adversarial inchangés ; âges en lettres et tranche « de N à M ans » lus par
P2-159 (adversarial : 12,7 % → 0 % d'âges non couverts, 15 âges en lettres).
Chemin : `ecluse_reid` seul (`run_reid_bench.dart`), pas `Ecluse.redact`. La
ligne « Généralisation appliquée » de l'adversarial en découle : ces 15
documents ont désormais un âge (sur les 385 autres, sortie identique, vérifié).

## Généralisation appliquée (P2-92, P2-102, P2-116, P2-132)

| Corpus | Avec suggestion | Refus | F médian avant → après 1er tour | Bande après 1er tour |
|---|---:|---:|---|---|
| QI réaliste | 170 | 0 | 74,0 → 2 002,0 | faible 170 |
| QI adversarial | 111 (109 avant P2-159) | 0 | 5,0 → 2 320,0 (6,0 → 2 466,1) | faible 103, moyen 7, élevé 1 |
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
| réaliste, largeur 90 | 84 | 27,7 % | 0 % | 9,2 % | **9,3 %** | 0 |
| réaliste, largeur 60 | 256 | 27,6 % | 1,3 % | 0,5 % | **8,6 %** | 2 |
| adversarial, 60 et 90 | 7 et 0 | 13,9 % | 1,9 % | 0 % | **7,2 %** (inchangé) | 0 |
| témoin, 60 et 90 | 292 et 12 | | | | **0 prédiction** | 0 |

Corpus structurel (rappel ; sans recoupe : 100 % partout). Deux chemins,
à ne pas confondre :

| Largeur | Chemin | NIR | RPPS | IBAN | FINESS | Total |
|---|---|---:|---:|---:|---:|---:|
| 90 | **`Ecluse.redact`** (ce que reçoit le LLM) | 269/269 | 166/166 | 214/214 | 129/129 | **778/778** |
| 60 | **`Ecluse.redact`** (ce que reçoit le LLM) | 269/269 | 166/166 | 214/214 | 129/129 | **778/778** (777/778 avant P2-158) |
| 90 | moteur seul (`ecluse_core`) | 100 % | 100 % | 87,4 % | 100 % | 96,5 % |
| 60 | moteur seul (`ecluse_core`) | 91,8 % | 90,4 % | 72,9 % | 100 % | 87,7 % |

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
les noms sont stables (la civilité seule, cf. P2-12) et les
établissements/adresses coupés en deux lignes fuient en partie. FINESS :
inchangé (aucun rappel perdu, 42 faux positifs SIREN comme avant).

¹ Refus explicites du détecteur de tableaux (`TableauAmbiguException`,
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
