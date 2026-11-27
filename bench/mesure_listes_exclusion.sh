#!/usr/bin/env bash
# P2-308 (mesure) : inventaire des listes d'exclusion des noms et sonde
# d'homonymes par `Ecluse.redact` (chemin du produit). Rien n'est corrigé.
# Depuis la racine du dépôt (graine fixe, ≈ 1 min) :
#     bash bench/mesure_listes_exclusion.sh [DOSSIER_DE_TRAVAIL]
set -Eeuo pipefail
R=$(pwd)
W=${1:-$(mktemp -d)}
mkdir -p "$W"
export PATH="$PATH:/opt/dart-sdk/bin:$HOME/.pub-cache/bin"
python3 bench/listes_exclusion.py inventaire
python3 bench/listes_exclusion.py sonde --out "$W/sonde.jsonl"
(cd "$R/packages/ecluse_redact" && dart run bin/run_gardes_avertissements.dart "$W/sonde.jsonl" "$W/pred.jsonl" < /dev/null)
python3 bench/listes_exclusion.py analyse "$W/sonde.jsonl:$W/pred.jsonl"
