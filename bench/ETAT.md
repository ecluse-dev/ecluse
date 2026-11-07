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

## Entités floues (corpus flous v2, 400 documents chacun)

Fuite au caractère (part des caractères annotés restés en clair).

| Corpus | nom | adresse | établissement | **global** | FP témoin | Restaurations non identiques¹ |
|---|---:|---:|---:|---:|---:|---:|
| réaliste | 27,7 % | 0 % | 0 % | **7,5 %** | | 0 |
| adversarial | 18,3 % | 1,9 % | 0 % | **9,3 %** | | 61 |
| témoin | | | | | **0** | 0 |
| réaliste en minuscules | 2,2 % | 0 % | 0 % | **0,6 %** | | 0 |
| adversarial en minuscules | 5,9 % (P2-139) | 1,9 % | 0 % | **3,3 %** | | 58³ |
| témoin en minuscules | | | | | **0** | 0 |
| réaliste en capitales | 2,2 % | 0 % | 0 % | **0,6 %** | | 0 |
| adversarial en capitales | 5,9 % (P2-139) | 1,9 % | 0 % | **3,3 %** | | 52 |
| témoin en capitales | | | | | **0** | 0 |
| faux amis prénoms (P2-124) | | | | | **0** | 0 |
| réaliste en casse de phrase (P2-138) | 2,2 % | 0 % | 0 % | **0,6 %** | | 0 |
| adversarial en casse de phrase (P2-138) | 9,0 % (P2-139) | 1,9 % | 0 % | **4,8 %** | | 58³ |
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

## Quasi-identifiants (`ecluse_reid`, corpus QI, 400 documents)

| Corpus | âge P / R | lieu P / R | profession P / R | Non couverts (âge / lieu / prof.) |
|---|---|---|---|---|
| réaliste | 100 / 100 % | 88,2 / 100 % | 100 / 100 % | 0 / 0 / 0 % |
| adversarial | 100 / 95,5 % | 92,3 / 100 % | 100 / 96,2 % | 12,7 / 0 / 2,0 % |
| témoin | 412 extractions à tort, 337 documents sur 400 ; **57 / 57 après P2-136, 0 après P2-142** | | | |

Identique à `bench/README.md` (P2-03b) au commit `d85fb84` ; témoin corrigé
ensuite par P2-136 (durées, communes-mots courants), réaliste et
adversarial inchangés.

## Généralisation appliquée (P2-92, P2-102, P2-116, P2-132)

| Corpus | Avec suggestion | Refus | F médian avant → après 1er tour | Bande après 1er tour |
|---|---:|---:|---|---|
| QI réaliste | 170 | 0 | 74,0 → 2 002,0 | faible 170 |
| QI adversarial | 109 | 0 | 6,0 → 2 466,1 | faible 101, moyen 7, élevé 1 |
| QI témoin | 0 | 0 | — | — |
| lieu (810 documents) | 24 | 0 | F recalculé = F simulé (24/24) | élevé 1, moyen 20, faible 3 |

## Dossiers (cohérence des jetons, avec `Dossier`)

| Corpus | Collisions | Fausses fusions | Restaurations non identiques |
|---|---:|---:|---:|
| réaliste | 0 / 557 | 0 / 935 | 0 / 397 |
| adversarial | 7 / 445 (1,6 %) | 7 / 596 (1,2 %) | 52 / 398 (13,1 %) |
| témoin | 0 / 757 | 0 / 757 | 0 / 396 |

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
