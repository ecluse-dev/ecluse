#!/usr/bin/env bash
# P2-303 (mesure) : identifiants vrais écartés par une garde, avec ou sans
# avertissement, par `Ecluse.redact` (chemin du produit). Rien n'est corrigé.
# Depuis la racine du dépôt (graine 42, ≈ 1 min) :
#     bash bench/mesure_gardes_silencieuses.sh [DOSSIER_DE_TRAVAIL]
set -Eeuo pipefail
R=$(pwd)
W=${1:-$(mktemp -d)}
mkdir -p "$W"
export PATH="$PATH:/opt/dart-sdk/bin:$HOME/.pub-cache/bin"
python3 bench/generate_sonde_gardes.py --n 40 --seed 42 --out "$W/sonde_g.jsonl" > /dev/null
python3 bench/generate_sonde_gardes_silencieuses.py --n 40 --seed 42 --out "$W/sonde_gs.jsonl" > /dev/null
for s in g gs; do
  (cd "$R/packages/ecluse_redact" && dart run bin/run_gardes_avertissements.dart "$W/sonde_$s.jsonl" "$W/pred_$s.jsonl" < /dev/null)
done
python3 bench/analyse_gardes_silencieuses.py "$W/sonde_g.jsonl:$W/pred_g.jsonl" "$W/sonde_gs.jsonl:$W/pred_gs.jsonl"
