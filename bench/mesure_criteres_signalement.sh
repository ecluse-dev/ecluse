#!/usr/bin/env bash
# P2-280 (mesure) : dump, par `Ecluse.redact`, des suites de mots-nombres
# (≥ 9) et de leur contexte sur les corpus de P2-274 ; l'évaluation des critères
# se fait ensuite hors ligne par `score_criteres_signalement.py`. Rien n'est
# corrigé : le patch est appliqué le temps de la mesure puis rétabli (trap).
# Prérequis (racine du dépôt, graine 42) : les corpus de `mesure_seuil_signalement.sh`.
# Usage : bash bench/mesure_criteres_signalement.sh DOSSIER_DE_SORTIE
set -Eeuo pipefail
R=$(pwd)
OUT=${1:?dossier de sortie}
mkdir -p "$OUT"
trap 'git -C "$R" checkout -- packages' EXIT
export PATH="$PATH:/opt/dart-sdk/bin:$HOME/.pub-cache/bin"
python3 bench/criteres_signalement_patch.py "$R"
T=$R/bench/transcrit
cd packages/ecluse_redact
for c in corpus_temoin_mots_nombres_dur corpus_temoin_mots_nombres corpus_dicte_non_valide_mot_perdu corpus_dicte_non_valide_cle_fausse; do
  rm -f "$OUT/$c.criteres"
  ECLUSE_CRITERES="$OUT/$c.criteres" dart run bin/run_temoin_nombres_dictes.dart "$T/$c.jsonl" "$OUT/$c.pred.jsonl" < /dev/null
done
echo "mesure terminée : $OUT"
