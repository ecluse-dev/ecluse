#!/usr/bin/env bash
# P2-323 : documents où `Ecluse.redact` masque une entité `siren`, par corpus
# propre (chemin du produit, graine 42). Lancé avant et après P2-323, la
# différence est le masquage à tort nouveau du SIRET de clé juste sans le mot
# « siret » et de la TVA sans libellé. Depuis la racine du dépôt, APRÈS
# `bash bench/etat.sh` (qui écrit les corpus sous bench/{flou,transcrit}/) :
#     bash bench/mesure_siret_tva_a_tort.sh [DOSSIER_DE_TRAVAIL] [DOSSIER_ECLUSE_REDACT]
# Le second argument pointe vers un autre `packages/ecluse_redact` (un
# worktree de `main` pour la mesure « avant »). ≈ 1 min.
# Sortie : « corpus | documents | documents avec une entité siren ». Aucune
# valeur n'est lue ni écrite : seuls des comptes.
set -Eeuo pipefail
R=$(pwd)
W=${1:-$(mktemp -d)}
D=${2:-$R/packages/ecluse_redact}
mkdir -p "$W"
export PATH="$PATH:/opt/dart-sdk/bin:$HOME/.pub-cache/bin"
CORPUS=(
  "temoin_480:$W/temoin_480.jsonl"
  "temoin_sans_personne_200000:$W/sans_pii_200k.jsonl"
  "durci_elargi_ocr:$R/bench/flou/corpus_faux_accords_ocr_dur.jsonl"
  "mots_nombres_durci_elargi:$R/bench/transcrit/corpus_faux_accords_mn_dur.jsonl"
  "commune_suivie:$R/bench/flou/corpus_flou_commune_suivie.jsonl"
  "libelle_fort:$R/bench/flou/corpus_libelle_fort.jsonl"
  "v3:$R/bench/corpus.jsonl"
)
[ -s "$W/temoin_480.jsonl" ] || python3 "$R/bench/generate_corpus_temoin_sans_pii.py" --n 480 --seed 42 --out "$W/temoin_480.jsonl" > /dev/null
[ -s "$W/sans_pii_200k.jsonl" ] || python3 "$R/bench/generate_corpus_temoin_sans_pii.py" --n 200000 --seed 42 --out "$W/sans_pii_200k.jsonl" > /dev/null
echo "corpus | documents | documents avec une entité siren"
for c in "${CORPUS[@]}"; do
  nom=${c%%:*}; f=${c#*:}
  if [ ! -s "$f" ]; then echo "ÉCHEC : $nom absent ($f)"; continue; fi
  out=$W/pred_$nom.jsonl
  rm -f "$out"
  (cd "$D" && dart run bin/run_gardes_avertissements.dart "$f" "$out" < /dev/null) > /dev/null 2>&1 || { echo "ÉCHEC : $nom"; continue; }
  python3 - "$nom" "$out" <<'PY'
import json, sys
n = a = 0
for l in open(sys.argv[2], encoding="utf-8"):
    if not l.strip():
        continue
    n += 1
    if any(e["type"] == "siren" for e in json.loads(l)["entities"]):
        a += 1
print(f"{sys.argv[1]} | {n} | {a}")
PY
done
