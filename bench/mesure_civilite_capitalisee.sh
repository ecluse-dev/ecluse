#!/usr/bin/env bash
# P2-322 (mesure) : civilité capitalisée devant un mot en minuscules, par
# `Ecluse.redact` (chemin du produit). Rien n'est corrigé. Depuis la racine du
# dépôt, APRÈS `bash bench/etat.sh` (qui écrit les corpus témoins sous
# bench/{flou,dossiers,transcrit}/) ; graine 42 ; quelques minutes :
#     bash bench/mesure_civilite_capitalisee.sh [DOSSIER_DE_TRAVAIL]
set -Eeuo pipefail
R=$(pwd)
W=${1:-$(mktemp -d)}
mkdir -p "$W"
export PATH="$PATH:/opt/dart-sdk/bin:$HOME/.pub-cache/bin"
run() { (cd "$R/packages/ecluse_redact" && dart run bin/run_gardes_avertissements.dart "$1" "$2" < /dev/null); }
echo "## sonde : treize listes x quatre civilités capitalisées, mot en minuscules"
python3 bench/civilite_capitalisee.py sonde --out "$W/sonde.jsonl"
run "$W/sonde.jsonl" "$W/pred_sonde.jsonl"
python3 bench/civilite_capitalisee.py analyse "$W/sonde.jsonl:$W/pred_sonde.jsonl"
echo "## coût d'un signalement sur les témoins du dépôt"
python3 bench/generate_corpus_tournures_sans_nom.py --n 400 --seed 42 --out "$W/tournures_sans_nom.jsonl" > /dev/null
python3 bench/generate_corpus_tournures_personne.py --seed 42 --out "$W/tournures_personne.jsonl" > /dev/null
python3 bench/generate_corpus_prenom_verbe.py --seed 42 --out "$W/prenom_verbe.jsonl" > /dev/null
{
  ls bench/corpus.jsonl bench/flou/corpus_*.jsonl bench/dossiers/corpus_*.jsonl \
     bench/transcrit/corpus_*.jsonl "$W"/tournures_sans_nom.jsonl \
     "$W"/tournures_personne.jsonl "$W"/prenom_verbe.jsonl 2>/dev/null
} | grep -v -e 'balayage' -e '_l60' -e '_l90' -e '\.traites' | sort > "$W/liste.txt"
# Texte de soin sans aucune personne (P2-246), 200 000 documents : le témoin le
# plus proche d'un texte naturel du dépôt (non versionné, généré ici).
python3 bench/generate_corpus_temoin_sans_pii.py --n 200000 --seed 42 --out "$W/sans_pii_200k.jsonl" > /dev/null
FICHIERS=("$W/sans_pii_200k.jsonl")
while read -r f; do
  [ "$(wc -l < "$f")" -gt 31200 ] && continue
  FICHIERS+=("$f")
done < "$W/liste.txt"
python3 bench/civilite_capitalisee.py temoins --out "$W/temoins.jsonl" "${FICHIERS[@]}"
run "$W/temoins.jsonl" "$W/pred_temoins.jsonl"
python3 bench/civilite_capitalisee.py analyse_temoins "$W/temoins.jsonl:$W/pred_temoins.jsonl"
