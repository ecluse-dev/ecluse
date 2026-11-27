#!/usr/bin/env bash
# P2-314 (mesure) : bruit de l'avertissement des homonymes en texte tout en
# minuscules et options pour le réduire, par `Ecluse.redact` (chemin du produit).
# Rien n'est corrigé. Depuis la racine du dépôt (graine 42, ≈ 5 min ;
# bench/corpus.jsonl doit exister : voir CLAUDE.md « Commandes ») :
#     bash bench/mesure_homonymes_minuscules.sh [DOSSIER_DE_TRAVAIL]
set -Eeuo pipefail
R=$(pwd)
W=${1:-$(mktemp -d)}
mkdir -p "$W"
export PATH="$PATH:/opt/dart-sdk/bin:$HOME/.pub-cache/bin"
python3 bench/generate_corpus_prenom_verbe.py --seed 42 --out "$W/pv.jsonl" > /dev/null
python3 bench/listes_exclusion.py sonde --out "$W/sonde.jsonl" > /dev/null
python3 bench/analyse_homonymes_minuscules.py prepare "$W"
for c in pv pv_min sonde sonde_min v3_min; do
  (cd "$R/packages/ecluse_redact" && dart run bin/run_gardes_avertissements.dart "$W/$c.jsonl" "$W/pred_$c.jsonl" < /dev/null)
done
python3 bench/analyse_homonymes_minuscules.py analyse "$W"
