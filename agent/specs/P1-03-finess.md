# P1-03 — FINESS et collision SIREN : faux positifs et pistes chiffrées

Type : `mesure`. Aucune modification du détecteur. Tout ce qui suit est
reproductible avec le corpus v3 (`--n 1000 --seed 42`).

## 1. Reproduction

```bash
python3 bench/generate_corpus.py --n 1000 --seed 42 --out bench/corpus.jsonl
cd packages/ecluse_bench && dart run bin/run_ecluse.dart \
  ../../bench/corpus.jsonl ../../bench/predictions_ecluse.jsonl
python3 bench/score.py --corpus bench/corpus.jsonl \
  --pred "Ecluse=bench/predictions_ecluse.jsonl"
```

Référence : FINESS 129 TP, 42 FP, 0 FN → précision 75,4 %, rappel 100 %.
Le script d'analyse (paragraphes 2 et 3) rejoue les prédictions en
classant chaque détection `finess` selon son contexte (40 caractères de
chaque côté, comme `FinessDetector._contextWindow`).

## 2. Classement des 42 faux positifs

| Cause | Nombre | Part |
|---|---:|---:|
| SIREN (Luhn valide, 9 chiffres, gabarit « Le SIREN de la société est … ») | 42 | 100 % |
| SIRET tronqué | 0 | 0 % |
| Fenêtre de 9 chiffres dans un NIR / RPPS / IBAN (invalide ou non) | 0 | 0 % |
| Autre nombre de 9 chiffres valide par coïncidence | 0 | 0 % |

- Les 42 FP contiennent tous le mot « siren » dans leur contexte, aucun le
  mot « finess » : ils sont donc captés à confiance basse (0,5).
- Aucun SIRET tronqué : le garde-fou `(?<![0-9])…(?![0-9])` empêche une
  fenêtre de 9 chiffres à l'intérieur d'un SIRET de 14 chiffres.
- Aucun FP de forme espacée (0/42), alors que 49 des 129 FINESS vrais sont
  espacés : l'espacement n'est pas en cause.
- Les 129 FINESS vrais se répartissent en 86 avec « finess » à proximité
  (confiance 0,9) et 43 sans (confiance 0,5, gabarit « La structure porte
  le code … »).

## 3. Pistes chiffrées (même corpus)

| Piste | TP | FP | Précision | Rappel |
|---|---:|---:|---:|---:|
| Référence (état actuel) | 129 | 42 | 75,4 % | 100 % |
| A. Contexte « finess » obligatoire (supprimer la confiance basse) | 86 | 0 | 100 % | **66,7 %** |
| B. Rejeter si « siren » / « siret » dans le contexte | 129 | 0 | 100 % | 100 % |
| C. Préfixe départemental valide (01–95, 97, 98) | 129 | 42 | 75,4 % | 100 % |
| B + C | 129 | 0 | 100 % | 100 % |
| A + C | 86 | 0 | 100 % | 66,7 % |

Lecture :

- **A** élimine tous les FP mais perd un FINESS vrai sur trois : exactement
  les 43 sans contexte. Inacceptable avec la règle « refus explicite
  plutôt qu'échec silencieux » : une fuite en échange de précision.
- **B** est parfait sur ce corpus (aucun FINESS vrai n'a « siren » ou
  « siret » dans son contexte). **Ce résultat est un artefact du
  générateur** (voir §4) : il ne dit rien du gain réel.
- **C** n'apporte rien ici : les 42 SIREN ont tous un préfixe admissible
  (sur des préfixes tirés au hasard, ~3 % seulement seraient hors de
  01–95/97/98 ; attendu ≈ 1 sur 42, observé 0). Le détecteur ne le
  vérifie d'ailleurs volontairement pas (voir sa documentation : format
  outre-mer et Corse incertains).

## 4. Limites de cette mesure (à lire avant de décider)

1. **Circularité.** Le corpus ne contient qu'un seul gabarit SIREN,
   toujours avec le mot « SIREN » dans la même phrase. Toute piste lexicale
   négative (B) est donc testée sur le cas qu'elle a été conçue pour
   attraper. Un vrai document peut afficher un SIREN sans le mot
   (« RCS Metz 552 100 554 », « TVA FR 12 552100554 »), où B ne ferait rien.
2. **Pas de FINESS « voisin » d'un SIREN.** Le corpus n'a pas de phrase du
   type « FINESS 123456789, SIREN 987654321 ». B, appliqué naïvement, ferait
   perdre le FINESS vrai (« siren » dans la fenêtre de 40 caractères). Une
   variante B′ (rejeter seulement si « siren/siret » est présent **et**
   « finess » absent du contexte) donne les mêmes chiffres ici et évite ce
   cas ; non mesurable sans nouveau gabarit.
3. **Aucun SIREN réel.** Les SIREN du corpus sont des nombres aléatoires à
   clé Luhn ; leur distribution de premiers chiffres n'est pas celle du
   répertoire SIRENE. La piste C ne peut pas être évaluée sérieusement.
4. **Liste officielle FINESS** (appartenance du numéro au fichier national,
   open data) : de loin la piste la plus discriminante en réel, mais elle
   n'est pas mesurable ici — les FINESS synthétiques sont aléatoires et ne
   figurent dans aucune liste, le rappel mesuré serait ~0 %. Elle impose en
   outre d'embarquer un jeu de données (taille, mise à jour, licence) :
   décision d'architecture, pas de simple détecteur.

## 5. Recommandation (pour le mainteneur)

1. Ne pas adopter A : perte de rappel de 33 points pour un gain de
   précision qu'on obtient autrement.
2. Si une correction est voulue, B′ est la moins coûteuse (quelques lignes,
   pas de donnée). Avant de la livrer, **ajouter au corpus** (tâche `code`
   séparée, règle « mesurer avant de corriger ») : des SIREN sans le mot
   « SIREN » (RCS, TVA, Kbis), et des phrases contenant à la fois FINESS et
   SIREN. Sans cela le gain annoncé (75,4 → 100 %) est un artefact.
3. Ne pas investir dans C tant qu'on n'a pas une source fiable sur les
   préfixes (outre-mer, Corse) ; gain mesuré : 0.
4. Garder en tête que le coût d'un FP SIREN est un sur-masquage d'un
   identifiant d'organisation, pas une fuite (cf. `NOTES_SECURITE`) : la
   précision FINESS de 75,4 % est une limite à documenter, pas un défaut
   bloquant.
5. Si la précision FINESS devient un argument commercial, la liste
   officielle (§4.4) est la seule piste qui change l'ordre de grandeur ;
   elle mérite une spec dédiée.

## 6. Ce qui reste incertain

- Les chiffres B/B′ valent pour ce générateur, pas pour des documents réels.
- Le seuil de 40 caractères pour le contexte n'a pas été exploré.
- Aucune donnée réelle n'a été utilisée (règle n°1 de `CLAUDE.md`).
