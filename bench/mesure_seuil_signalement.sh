#!/usr/bin/env bash
# P2-274 (mesure) : seuil du signalement « nombre dicté non reconnu »
# (`_kSuiteNonReconnue`) par `Ecluse.redact`. Rien n'est corrigé : le fichier de
# production est modifié le temps de la mesure puis rétabli (trap), jamais commité.
#
# Prérequis (racine du dépôt, graine 42) : les corpus de `mesure_nombres_dictes_k.sh`
# puis
#   python3 bench/generate_corpus_dicte_non_valide.py --in-dir bench/transcrit --out-dir bench/transcrit --seed 42
# Usage : bash bench/mesure_seuil_signalement.sh SORTIE_DIR SEUIL
set -Eeuo pipefail
R=$(pwd)
OUT=${1:?dossier de sortie}
S=${2:?seuil}
F="$R/packages/ecluse_redact/lib/src/nombres_dictes.dart"
mkdir -p "$OUT"
cp "$F" "$OUT/nombres_dictes.orig"
trap 'cp "$OUT/nombres_dictes.orig" "$F"' EXIT
sed -i "s/^const int _kSuiteNonReconnue = [0-9]*;/const int _kSuiteNonReconnue = $S;/" "$F"
grep -n "^const int _kSuiteNonReconnue" "$F"
T=$R/bench/transcrit
cd "$R/packages/ecluse_redact"
run() { dart run bin/run_temoin_nombres_dictes.dart "$1" "$2" < /dev/null; }
run "$T/corpus_temoin_mots_nombres_dur.jsonl" "$OUT/dur.jsonl"
run "$T/corpus_temoin_mots_nombres.jsonl" "$OUT/orig.jsonl"
run "$T/corpus_dicte_non_valide_mot_perdu.jsonl" "$OUT/perdu.jsonl"
run "$T/corpus_dicte_non_valide_cle_fausse.jsonl" "$OUT/fausse.jsonl"
echo "== témoin durci (630), seuil=$S"
python3 "$R/bench/score_temoin_dur.py" --corpus "$T/corpus_temoin_mots_nombres_dur.jsonl" --pred "$OUT/dur.jsonl" --exemples 0 | grep -E "^codes|^TOTAL"
python3 - "$OUT/orig.jsonl" <<'PY'
import json, sys
d = [json.loads(l) for l in open(sys.argv[1])]
print("témoin d'origine (300) :", sum(bool(x["entities"]) for x in d), "masquées,", sum(bool(x["signalements"]) for x in d), "signalées")
PY
echo "== identifiants dictés abîmés : mot perdu, seuil=$S"
python3 "$R/bench/score_dicte_non_valide.py" --corpus "$T/corpus_dicte_non_valide_mot_perdu.jsonl" --pred "$OUT/perdu.jsonl"
echo "== identifiants dictés abîmés : clé fausse, seuil=$S"
python3 "$R/bench/score_dicte_non_valide.py" --corpus "$T/corpus_dicte_non_valide_cle_fausse.jsonl" --pred "$OUT/fausse.jsonl"
