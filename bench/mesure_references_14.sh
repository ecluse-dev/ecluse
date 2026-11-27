#!/usr/bin/env bash
# P2-311 (mesure) : coût d'un masquage des SIRET sans le mot « siret » et des TVA
# sans libellé, sur des textes logistiques synthétiques sans donnée personnelle,
# par `Ecluse.redact` (chemin du produit). Rien n'est corrigé.
# Depuis la racine du dépôt (graine 42, ≈ 30 s) :
#     bash bench/mesure_references_14.sh [DOSSIER_DE_TRAVAIL]
set -Eeuo pipefail
R=$(pwd)
W=${1:-$(mktemp -d)}
mkdir -p "$W"
export PATH="$PATH:/opt/dart-sdk/bin:$HOME/.pub-cache/bin"
python3 bench/generate_corpus_references_14.py --n 300 --seed 42 --out "$W/references_14.jsonl"
(cd "$R/packages/ecluse_redact" && dart run bin/run_gardes_avertissements.dart "$W/references_14.jsonl" "$W/pred_references_14.jsonl" < /dev/null)
python3 bench/analyse_references_14.py "$W/references_14.jsonl:$W/pred_references_14.jsonl"
