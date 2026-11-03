# Mesurer un NER local sur les corpus flous (P2-88)

Ce document dit comment produire et scorer les prédictions d'un modèle NER pour
le critère GO/STOP de `agent/specs/P2-01.md`, **sans** ajouter le modèle ni une
dépendance ONNX au dépôt (règle 7 de `CLAUDE.md`). Le modèle tourne sur le poste
du mainteneur ; seul le score revient dans le dépôt, sous forme de rapport.

Candidat de départ : `agent/specs/P2-86.md` (CamemBERT PII V2). Rappel : aucun
GO n'est possible tant que la licence de ses données d'entraînement reste
illisible (condition STOP n° 2 de P2-01), même si la mesure est bonne.

## 1. Corpus

Les trois corpus flous, générés et jamais versionnés (`bench/flou/`) :

```bash
mkdir -p bench/flou
python3 bench/generate_corpus_flou.py --n 400 --seed 42 --out-dir bench/flou
```

Types annotés : `nom`, `adresse`, `date_naissance`, `telephone`, `email`,
`etablissement`. Un `nom` couvre la civilité, le prénom et le patronyme d'un
seul tenant (`Mme Odile Marchetti`).

## 2. Format des prédictions

Celui que `score_flou.py` lit déjà, une ligne par document, offsets en
**caractères** dans le texte d'origine (pas en jetons du modèle) :

```json
{"id": 12, "entities": [{"type": "nom", "start": 40, "end": 59}]}
```

- Un document sans prédiction a quand même sa ligne, avec `"entities": []`.
- `end` est exclusif, comme dans le corpus.
- Un type inconnu du corpus n'est pas une erreur : il compte pour la fuite au
  caractère (tout caractère couvert est protégé), pas pour le strict ni le
  souple. Mieux vaut le garder que le jeter.

## 3. Correspondance des labels (candidat 1)

Labels lus sur la fiche du modèle (P2-86 § 2.1) ; la liste complète est dans
`config.json` (`id2label`) du modèle et **doit être relue** avant la mesure.

| Labels du modèle | Type du corpus | Remarque |
|---|---|---|
| `NOM_PERSONNE`, `PRENOM_PERSONNE` | `nom` | Fusionner les spans voisins séparés par au plus un blanc |
| `NUMERO_VOIE`, `NOM_VOIE`, `CODE_POSTAL`, `VILLE` | `adresse` | Fusionner les spans voisins séparés par des blancs, une virgule ou un saut de ligne |
| `TELEPHONE` | `telephone` | |
| `EMAIL` | `email` | |
| `NOM_SOCIETE` | `etablissement` | Le plus proche ; le modèle vise le juridique et le chiffre, pas le médico-social |
| label de date de naissance, s'il existe | `date_naissance` | Nom exact à lire dans `config.json` |
| `NUM_SECURITE_SOCIALE`, `IBAN` et autres identifiants | garder le label tel quel | Couverts par les détecteurs structurels ; utile seulement pour compter les collisions (condition B de P2-01) |

La civilité (`Mme`, `Dr`) n'est en général pas un label du modèle : le score
strict sur `nom` sera donc bas par construction. C'est la fuite au caractère qui
décide (P2-01 § 4), et Écluse garde de toute façon la civilité visible.

## 4. Produire les prédictions (poste du mainteneur)

Avec le spike existant (`onnxruntime` + `transformers`), le pipeline de
classification de jetons donne déjà des offsets en caractères :

```python
from transformers import pipeline
ner = pipeline("token-classification", model=CHEMIN_DU_MODELE,
               aggregation_strategy="simple", stride=64)
for ligne in corpus:
    spans = [(e["entity_group"], e["start"], e["end"]) for e in ner(ligne["text"])]
    # puis : correspondance du § 3, fusion des voisins, écriture JSONL du § 2
```

Deux pièges :

- **Longueur** : CamemBERT lit au plus 512 jetons. Sans `stride` (ou un
  découpage par paragraphes), la fin d'un long document est **ignorée en
  silence** : la fuite mesurée serait juste, mais imputée au modèle alors
  qu'elle vient du découpage.
- **Quantification** : mesurer la version int8 qui serait livrée, pas seulement
  le FP32. Le plafond proposé par P2-01 vaut pour le modèle quantifié.

Noter aussi, pour la condition E de P2-01 : la latence au 95e centile sur des
documents d'environ 1 000 mots, la taille sur disque et la mémoire, sur la
machine de référence (P2-87).

## 5. Scorer

Trois mesures par corpus : Écluse seul (référence de P2-02), NER seul, et
Écluse puis NER, c'est-à-dire l'union des deux fichiers.

```bash
for c in realiste adversarial temoin; do
  (cd packages/ecluse_redact && dart run bin/run_redact_bench.dart \
     ../../bench/flou/corpus_flou_$c.jsonl ../../bench/flou/pred_$c.jsonl)
  python3 - "$c" <<'PY'
import json, sys
c = sys.argv[1]
def lire(p):
    return {d["id"]: d["entities"] for d in map(json.loads, open(p, encoding="utf-8"))}
a = lire(f"bench/flou/pred_{c}.jsonl")
b = lire(f"bench/flou/pred_ner_{c}.jsonl")
with open(f"bench/flou/pred_union_{c}.jsonl", "w", encoding="utf-8") as f:
    for i in sorted(a.keys() | b.keys()):
        f.write(json.dumps({"id": i, "entities": a.get(i, []) + b.get(i, [])}) + "\n")
PY
  (cd bench && python3 score_flou.py --corpus flou/corpus_flou_$c.jsonl \
     --pred "Ecluse=flou/pred_$c.jsonl" \
     --pred "NER=flou/pred_ner_$c.jsonl" \
     --pred "Ecluse+NER=flou/pred_union_$c.jsonl")
done
```

L'union est une **borne haute** de ce que donnerait l'intégration : dans
Écluse, `resolveOverlaps` fera passer les détecteurs structurels avant le NER,
et un span NER ne pourra pas écraser un identifiant validé (condition B).

## 6. Ce qui revient dans le dépôt

Un rapport (tâche `mesure`, sans correction) avec, par corpus et pour les trois
lignes : strict, souple, fuite au caractère par type ; le taux de documents du
témoin qui ont au moins une détection ; latence, taille et mémoire. **Jamais**
les fichiers de prédictions ni le modèle.
