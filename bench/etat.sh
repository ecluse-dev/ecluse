#!/usr/bin/env bash
# Rejoue tous les corpus du dépôt sur l'état courant (P2-130) et imprime
# les lignes de synthèse. Graine 42 partout. Depuis la racine du dépôt :
#     bash bench/etat.sh > etat.log 2>&1
# Les fichiers générés vont dans bench/{flou,qi,dossiers,patho,transcrit}/,
# non versionnés. Presidio n'est pas rejoué ici (environnement à part,
# voir README « Reproduire »).
#
# Fiabilité (P2-168). Le tableau de bord ne doit ni taire une ligne attendue
# ni masquer un échec :
# - `produit` lance une commande qui écrit un fichier : un code de sortie non
#   nul, un fichier absent ou vide s'impriment « ÉCHEC : … » (le fichier est
#   supprimé avant, donc jamais un ancien résultat lu à la place) ;
# - `montre` filtre la sortie d'une commande : un code non nul ou aucune ligne
#   retenue s'impriment « ÉCHEC : … » / « section vide » ; seuls les témoins
#   sans entité annotée ont le droit de ne rien afficher, et le disent ici ;
# - à la fin, `verifie_etat.py` compare la sortie à la liste des lignes
#   attendues (`bench/etat_attendu.py`) ; le script sort en erreur au premier
#   ÉCHEC ou à la première ligne attendue manquante.
# Les chiffres imprimés ne changent pas : ces garde-fous n'ajoutent que des
# lignes d'échec ou d'avertissement.
set -Eeuo pipefail
R=$(pwd)
B=$R/bench
mkdir -p "$B"/{flou,qi,dossiers,patho,transcrit,patronymes}
ERR=$(mktemp)
NONMAP=$(mktemp)
LOG=$(mktemp)
trap 'rm -f "$ERR" "$NONMAP" "$LOG"' EXIT
trap 'echo "ÉCHEC : commande inattendue en échec, ligne $LINENO (code $?)"' ERR

redact() { (cd "$R/packages/ecluse_redact" && dart run "bin/$1" "${@:2}" < /dev/null); }
reid() { (cd "$R/packages/ecluse_reid" && dart run "bin/$1" "${@:2}" < /dev/null); }
bench_pkg() { (cd "$R/packages/ecluse_bench" && dart run "bin/$1" "${@:2}" < /dev/null); }
dans_B() { (cd "$B" && "$@"); }

ECHECS=0
echec() { echo "ÉCHEC : $*"; ECHECS=$((ECHECS + 1)); }

# produit ÉTIQUETTE FICHIER COMMANDE… : la sortie standard est jetée, l'erreur
# standard gardée (dans $ERR, relue par l'appelant : ALERTE, REFUS). Rend 1 et
# imprime ÉCHEC si la commande échoue ou si FICHIER est absent ou vide.
produit() {
  local etiquette=$1 fichier=$2 code=0
  shift 2
  rm -f "$fichier"
  "$@" > /dev/null 2> "$ERR" || code=$?
  if [ "$code" -ne 0 ]; then
    echec "$etiquette : code $code ($(grep -m1 . "$ERR" | cut -c1-160))"
    return 1
  fi
  if [ ! -s "$fichier" ]; then
    echec "$etiquette : fichier de sortie absent ou vide"
    return 1
  fi
  # Types d'entité que le banc n'a pas dans sa table (stderr « ATTENTION »).
  awk '/^ATTENTION/{f=1;next} /^Ces types/{f=0} f&&NF{gsub(/ /,"");print}' "$ERR" >> "$NONMAP"
  return 0
}

# montre ÉTIQUETTE OPTIONS MOTIF N VIDE_PERMIS COMMANDE… : exécute la commande,
# affiche les N premières lignes (0 = toutes) de sa sortie qui correspondent à
# MOTIF (grep OPTIONS). Code non nul ou aucune ligne retenue : ÉCHEC, sauf si
# VIDE_PERMIS vaut « oui » (témoin sans entité annotée : rien à afficher).
montre() {
  local etiquette=$1 options=$2 motif=$3 n=$4 vide_permis=$5 code=0 sortie sel
  shift 5
  sortie=$("$@" 2> "$ERR") || code=$?
  if [ "$code" -ne 0 ]; then
    echec "$etiquette : code $code ($(grep -m1 . "$ERR" | cut -c1-160))"
    return 1
  fi
  # grep rend 1 s'il ne trouve rien : le cas est traité juste après.
  sel=$(printf '%s\n' "$sortie" | grep $options -e "$motif" || true)
  if [ -z "$sel" ]; then
    if [ "$vide_permis" = "oui" ]; then return 0; fi
    echec "section vide : $etiquette (aucune ligne ne correspond à $motif)"
    return 1
  fi
  if [ "$n" -gt 0 ]; then sel=$(printf '%s\n' "$sel" | sed -n "1,${n}p"); fi
  printf '%s\n' "$sel"
}

predites() { python3 -c "import json,sys;print('  entites predites',sum(len(json.loads(l)['entities']) for l in open(sys.argv[1])))" "$1"; }

tableau() {
# Aucun résultat d'un rejeu précédent ne doit pouvoir être relu à la place d'un
# résultat manquant : tout ce que le script produit est supprimé d'abord. Ces
# fichiers sont générés (graine 42), ignorés par git, jamais versionnés.
rm -f "$B"/corpus.jsonl "$B"/predictions_ecluse.jsonl \
  "$B"/{flou,qi,dossiers,patho,transcrit,patronymes}/*.jsonl "$B"/flou/*.traites
echo "## commit $(git rev-parse --short HEAD)"

echo "## v3 (identifiants structurels)"
produit "générateur v3" "$B/corpus.jsonl" python3 "$B/generate_corpus.py" --n 1000 --seed 42 --out "$B/corpus.jsonl" || true
if produit "v3, moteur seul" "$B/predictions_ecluse.jsonl" bench_pkg run_ecluse.dart ../../bench/corpus.jsonl ../../bench/predictions_ecluse.jsonl; then
  # TOTAL = tous types (siren compris) ; COMMUNS = types communs, siren retiré
  # de l'or et des prédictions (P2-261) ; « (e) » = ligne siren à part.
  montre "v3, score" -E "TOTAL|FINESS|COMMUNS|^Ecluse \(e\)" 6 non dans_B python3 score.py --corpus corpus.jsonl --pred "Ecluse=predictions_ecluse.jsonl" || true
fi

echo "## v3 transcrit"
produit "générateur transcrit" "$B/transcrit/corpus_transcrit_sans_ponctuation.jsonl" python3 "$B/generate_corpus_transcrit.py" --corpus "$B/corpus.jsonl" --seed 42 --out-dir "$B/transcrit" || true
for v in sans_ponctuation en_lettres; do
  echo "# $v"
  if produit "transcrit $v, moteur seul" "$B/transcrit/pred_$v.jsonl" bench_pkg run_ecluse.dart "../../bench/transcrit/corpus_transcrit_$v.jsonl" "../../bench/transcrit/pred_$v.jsonl"; then
    montre "transcrit $v, score" -E "TOTAL" 1 non dans_B python3 score.py --corpus "transcrit/corpus_transcrit_$v.jsonl" --pred "Ecluse=transcrit/pred_$v.jsonl" || true
  fi
done

echo "## v3 dictée : variantes de P2-160 (rappel = identifiant entièrement couvert ; fuite au caractère)"
for v in double_triple regional zero_o sans_traits_union; do
  echo "# $v : moteur seul (ecluse_core)"
  if produit "dictée $v, moteur seul" "$B/transcrit/pred_$v.jsonl" bench_pkg run_ecluse.dart "../../bench/transcrit/corpus_transcrit_$v.jsonl" "../../bench/transcrit/pred_$v.jsonl"; then
    montre "dictée $v, score" -E "TOTAL" 1 non dans_B python3 score.py --corpus "transcrit/corpus_transcrit_$v.jsonl" --pred "Ecluse=transcrit/pred_$v.jsonl" || true
  fi
done
for v in sans_ponctuation en_lettres double_triple regional zero_o sans_traits_union; do
  echo "# $v : Ecluse.redact (chemin du produit)"
  if produit "dictée $v, Ecluse.redact" "$B/transcrit/pred_redact_$v.jsonl" redact run_redact_bench.dart "../../bench/transcrit/corpus_transcrit_$v.jsonl" "../../bench/transcrit/pred_redact_$v.jsonl"; then
    montre "dictée $v, rappel Ecluse.redact" -E . 0 non python3 "$B/rappel_structurel.py" --fuite --corpus "$B/transcrit/corpus_transcrit_$v.jsonl" --pred "$B/transcrit/pred_redact_$v.jsonl" || true
  fi
done

echo "## témoin mots-nombres (P2-160) : Ecluse.redact, aucune entité annotée"
produit "générateur mots-nombres" "$B/transcrit/corpus_temoin_mots_nombres.jsonl" python3 "$B/generate_corpus_mots_nombres.py" --n 300 --seed 42 --out "$B/transcrit/corpus_temoin_mots_nombres.jsonl" || true
if produit "témoin mots-nombres, Ecluse.redact" "$B/transcrit/pred_temoin_mots_nombres.jsonl" redact run_redact_bench.dart "../../bench/transcrit/corpus_temoin_mots_nombres.jsonl" "../../bench/transcrit/pred_temoin_mots_nombres.jsonl"; then
  python3 -c "import json,sys;print('témoin mots-nombres :',sum(len(json.loads(l)['entities']) for l in open(sys.argv[1])),'prédictions sur',sum(1 for _ in open(sys.argv[1])),'phrases')" "$B/transcrit/pred_temoin_mots_nombres.jsonl"
fi

echo "## mots-nombres durci (P2-270, P2-275) : Ecluse.redact, aucune entité annotée"
# 630 phrases ordinaires denses en nombres (montants, horaires, adresses, codes) :
# toute prédiction est un masquage en trop (3 avant P2-273 pour « code »).
produit "générateur mots-nombres durci" "$B/transcrit/corpus_temoin_mots_nombres_dur.jsonl" python3 "$B/generate_corpus_mots_nombres_dur.py" --n 90 --seed 42 --out "$B/transcrit/corpus_temoin_mots_nombres_dur.jsonl" || true
if produit "mots-nombres durci, Ecluse.redact" "$B/transcrit/pred_temoin_mots_nombres_dur.jsonl" redact run_redact_bench.dart "../../bench/transcrit/corpus_temoin_mots_nombres_dur.jsonl" "../../bench/transcrit/pred_temoin_mots_nombres_dur.jsonl"; then
  python3 -c "import json,sys;print('mots-nombres durci :',sum(len(json.loads(l)['entities']) for l in open(sys.argv[1])),'prédictions sur',sum(1 for _ in open(sys.argv[1])),'phrases')" "$B/transcrit/pred_temoin_mots_nombres_dur.jsonl"
fi

echo "## signalements « nombre dicté non reconnu » à tort (P2-291) : Ecluse.redact (chemin du produit)"
# Phrases ordinaires sans aucune entité annotée : toute phrase signalée ou masquée
# est un signalement ou un masquage en trop. Le témoin durci (630, graine 42) et le
# témoin d'origine (300) sont ceux des deux sections ci-dessus ; le témoin neuf
# (630, graine 43) a été écrit pour P2-282 (mêmes familles, jamais lu avant).
# Avant P2-282 : durci 49, neuf 41, d'origine 0 phrases signalées à tort.
produit "générateur mots-nombres durci, graine 43" "$B/transcrit/corpus_temoin_mots_nombres_dur_g43.jsonl" python3 "$B/generate_corpus_mots_nombres_dur.py" --n 90 --seed 43 --out "$B/transcrit/corpus_temoin_mots_nombres_dur_g43.jsonl" || true
for t in "durci (630, graine 42):temoin_mots_nombres_dur" "neuf (630, graine 43):temoin_mots_nombres_dur_g43" "d'origine (300, graine 42):temoin_mots_nombres"; do
  nom=${t%%:*}; f=${t#*:}
  if produit "signalements à tort, témoin $nom, Ecluse.redact" "$B/transcrit/pred_signalements_$f.jsonl" redact run_temoin_nombres_dictes.dart "../../bench/transcrit/corpus_$f.jsonl" "../../bench/transcrit/pred_signalements_$f.jsonl"; then
    python3 "$B/compte_signalements_a_tort.py" "signalements à tort, témoin $nom" "$B/transcrit/pred_signalements_$f.jsonl"
  fi
done

echo "## fuite par OCR (P2-264, P2-268) : Ecluse.redact (chemin du produit)"
# « O »/« o » pour 0, « l »/« I » pour 1 : 1 200 positifs (5 types x 3 confusions
# x avec/sans libellé x 40), 400 témoins d'origine et 450 témoins durcis.
produit "générateur OCR" "$B/flou/corpus_ocr.jsonl" python3 "$B/generate_corpus_ocr.py" --n 40 --seed 42 --out "$B/flou/corpus_ocr.jsonl" || true
if produit "OCR, Ecluse.redact" "$B/flou/pred_ocr.jsonl" redact run_redact_bench.dart "../../bench/flou/corpus_ocr.jsonl" "../../bench/flou/pred_ocr.jsonl"; then
  montre "OCR, score" -E "^(TOTAL|témoin négatif)" 0 non dans_B python3 score_ocr.py --corpus flou/corpus_ocr.jsonl --pred flou/pred_ocr.jsonl || true
fi

echo "## OCR derrière un libellé, clé fausse (P2-275) : Ecluse.redact (chemin du produit)"
# NIR, RPPS et IBAN à clé fausse lus avec des lettres d'OCR, séparateurs multiples.
produit "générateur OCR clé fausse" "$B/flou/corpus_ocr_cle_fausse.jsonl" python3 "$B/generate_corpus_ocr_cle_fausse.py" --n 40 --seed 42 --out "$B/flou/corpus_ocr_cle_fausse.jsonl" || true
if produit "OCR clé fausse, Ecluse.redact" "$B/flou/pred_ocr_cle_fausse.jsonl" redact run_redact_bench.dart "../../bench/flou/corpus_ocr_cle_fausse.jsonl" "../../bench/flou/pred_ocr_cle_fausse.jsonl"; then
  montre "OCR clé fausse, score" -E "^TOTAL" 0 non dans_B python3 score_ocr.py --corpus flou/corpus_ocr_cle_fausse.jsonl --pred flou/pred_ocr_cle_fausse.jsonl || true
fi

echo "## sonde des gardes (P2-272, P2-278) : Ecluse.redact (chemin du produit)"
# 820 documents synthétiques d'identifiants à clé fausse (IBAN, NIR), de FINESS sans
# contexte et d'adresses avec arrondissement, par écriture : « couverts a/b » = identifiants
# entièrement masqués. Les trous connus (IBAN en paires, arrondissement) y sont suivis.
produit "générateur sonde" "$B/flou/corpus_sonde_gardes.jsonl" python3 "$B/generate_sonde_gardes.py" --n 40 --seed 42 --out "$B/flou/corpus_sonde_gardes.jsonl" || true
if produit "sonde, Ecluse.redact" "$B/flou/pred_sonde_gardes.jsonl" redact run_redact_bench.dart "../../bench/flou/corpus_sonde_gardes.jsonl" "../../bench/flou/pred_sonde_gardes.jsonl"; then
  montre "sonde, score" -E "^sonde " 0 non python3 "$B/score_gardes.py" --corpus "$B/flou/corpus_sonde_gardes.jsonl" --pred "$B/flou/pred_sonde_gardes.jsonl" --par famille,ecriture --lignes || true
fi

echo "## identifiants dictés abîmés (P2-274, P2-278) : Ecluse.redact (chemin du produit)"
# NIR et IBAN dictés dont un mot est perdu ou dont la clé est fausse (2 420 documents
# par variante) : « masqués » = entièrement masqués, « signalés seulement » = avertis sans
# être masqués, « rien » = en clair sans avertissement (le chiffre à suivre).
produit "générateur dictée abîmée" "$B/transcrit/corpus_dicte_non_valide_mot_perdu.jsonl" python3 "$B/generate_corpus_dicte_non_valide.py" --in-dir "$B/transcrit" --out-dir "$B/transcrit" --seed 42 || true
for v in mot_perdu cle_fausse; do
  echo "# $v"
  if produit "dictée abîmée $v, Ecluse.redact" "$B/transcrit/pred_dicte_non_valide_$v.jsonl" redact run_temoin_nombres_dictes.dart "../../bench/transcrit/corpus_dicte_non_valide_$v.jsonl" "../../bench/transcrit/pred_dicte_non_valide_$v.jsonl"; then
    montre "dictée abîmée $v, score" -E "^(nir|iban|TOTAL)" 0 non python3 "$B/score_dicte_non_valide.py" --corpus "$B/transcrit/corpus_dicte_non_valide_$v.jsonl" --pred "$B/transcrit/pred_dicte_non_valide_$v.jsonl" || true
  fi
done

echo "## faux accords par détecteur (P2-279, P2-284) : Ecluse.redact (chemin du produit)"
# Documents sans aucune entité annotée : tout masquage est un faux accord. Taux de
# DOCUMENTS à tort par détecteur, intervalle de Wilson à 95 % (`score_faux_accords.py`).
# 5 000 documents du témoin durci de P2-268 (5 x 1 000) et 5 600 phrases ordinaires de
# nombres en lettres (7 x 800). Les 200 000 documents sans donnée personnelle de
# P2-279 (≈ 10 min) restent à `bench/mesure_faux_accords.sh`.
produit "générateur OCR durci élargi" "$B/flou/corpus_faux_accords_ocr_brut.jsonl" python3 "$B/generate_corpus_ocr.py" --n 1 --n-dur 1000 --seed 42 --out "$B/flou/corpus_faux_accords_ocr_brut.jsonl" || true
produit "témoin durci élargi, extraction" "$B/flou/corpus_faux_accords_ocr_dur.jsonl" python3 -c '
import json, sys
with open(sys.argv[2], "w", encoding="utf-8") as f:
    for l in open(sys.argv[1], encoding="utf-8"):
        if json.loads(l)["presentation"] == "temoin_dur":
            f.write(l)
' "$B/flou/corpus_faux_accords_ocr_brut.jsonl" "$B/flou/corpus_faux_accords_ocr_dur.jsonl" || true
produit "générateur mots-nombres durci élargi" "$B/transcrit/corpus_faux_accords_mn_dur.jsonl" python3 "$B/generate_corpus_mots_nombres_dur.py" --n 800 --seed 42 --out "$B/transcrit/corpus_faux_accords_mn_dur.jsonl" || true
faux_accords_score() { python3 "$B/score_faux_accords.py" --exemples 0 "$@" | sed 's/^## /faux accords : /'; }
if produit "faux accords, témoin durci élargi, Ecluse.redact" "$B/flou/pred_faux_accords_ocr_dur.jsonl" redact run_faux_accords.dart "../../bench/flou/corpus_faux_accords_ocr_dur.jsonl" "../../bench/flou/pred_faux_accords_ocr_dur.jsonl"; then
  montre "faux accords, témoin durci élargi, score" -E "^faux accords : | documents \(" 0 non faux_accords_score --corpus "$B/flou/corpus_faux_accords_ocr_dur.jsonl" --pred "$B/flou/pred_faux_accords_ocr_dur.jsonl" --nom "témoin durci de P2-268, élargi" || true
fi
if produit "faux accords, mots-nombres durci élargi, Ecluse.redact" "$B/transcrit/pred_faux_accords_mn_dur.jsonl" redact run_faux_accords.dart "../../bench/transcrit/corpus_faux_accords_mn_dur.jsonl" "../../bench/transcrit/pred_faux_accords_mn_dur.jsonl"; then
  montre "faux accords, mots-nombres durci élargi, score" -E "^faux accords : | documents \(" 0 non faux_accords_score --corpus "$B/transcrit/corpus_faux_accords_mn_dur.jsonl" --pred "$B/transcrit/pred_faux_accords_mn_dur.jsonl" --nom "mots-nombres durci, élargi" --tout-en-dictees || true
fi

echo "## flou (entités floues) et variantes de casse"
produit "générateur flou" "$B/flou/corpus_flou_realiste.jsonl" python3 "$B/generate_corpus_flou.py" --n 400 --seed 42 --out-dir "$B/flou" || true
produit "variantes de casse (flou)" "$B/flou/corpus_flou_temoin_phrase.jsonl" python3 "$B/variantes_casse.py" "$B"/flou/corpus_flou_{realiste,adversarial,temoin}.jsonl || true
produit "générateur faux amis" "$B/flou/corpus_flou_fauxamis.jsonl" python3 "$R/bench/generate_corpus_faux_amis_prenoms.py" --n 400 --seed 42 --out "$B/flou/corpus_flou_fauxamis.jsonl" || true
for c in realiste adversarial temoin realiste_minuscules adversarial_minuscules temoin_minuscules realiste_majuscules adversarial_majuscules temoin_majuscules realiste_phrase adversarial_phrase temoin_phrase fauxamis; do
  echo "# $c"
  if produit "flou $c, Ecluse.redact" "$B/flou/etat_$c.jsonl" redact run_redact_bench.dart "../../bench/flou/corpus_flou_$c.jsonl" "../../bench/flou/etat_$c.jsonl"; then
    # grep -c rend 1 quand il compte 0 : le zéro est un résultat, pas un échec.
    n=$(grep -c ALERTE "$ERR" || true)
    echo "  restaurations non identiques (harmonisation, LIMITES 5.3) : $n"
    # Les témoins et les faux amis n'ont aucune entité annotée : pas de ligne de score.
    case "$c" in temoin*|fauxamis) vide=oui ;; *) vide=non ;; esac
    montre "flou $c, score" -E "^GLOBAL|^nom |^adresse |^etablissement " 0 "$vide" dans_B python3 score_flou.py --corpus "flou/corpus_flou_$c.jsonl" --pred "Ecluse=flou/etat_$c.jsonl" || true
    predites "$B/flou/etat_$c.jsonl"
  fi
done

echo "## quasi-identifiants (ecluse_reid)"
produit "générateur QI" "$B/qi/corpus_qi_realiste.jsonl" python3 "$B/generate_corpus_qi.py" --n 400 --seed 42 --out-dir "$B/qi" || true
for c in realiste adversarial temoin temoin_durees; do
  echo "# $c"
  if produit "QI $c, ecluse_reid" "$B/qi/pred_qi_$c.jsonl" reid run_reid_bench.dart "../../bench/qi/corpus_qi_$c.jsonl" "../../bench/qi/pred_qi_$c.jsonl"; then
    montre "QI $c, score" -E "^(age|lieu|profession|GLOBAL|TOTAL)|[Ee]xtractions" 6 non python3 "$B/score_qi.py" --corpus "$B/qi/corpus_qi_$c.jsonl" --pred "Ecluse=$B/qi/pred_qi_$c.jsonl" || true
  fi
done

echo "## quasi-identifiants par Ecluse.redact (P2-175) : patronyme en clair derrière un métier sans civilité"
for c in realiste adversarial; do
  echo "# $c"
  if produit "QI $c, Ecluse.redact" "$B/qi/pred_redact_qi_$c.jsonl" redact run_redact_bench.dart "../../bench/qi/corpus_qi_$c.jsonl" "../../bench/qi/pred_redact_qi_$c.jsonl"; then
    montre "QI $c, patronyme en clair" -E "^QI par|documents|patronyme" 0 non python3 "$B/score_qi_redact.py" --corpus "$B/qi/corpus_qi_$c.jsonl" --pred "$B/qi/pred_redact_qi_$c.jsonl" || true
  fi
done

echo "## généralisation appliquée"
for c in realiste adversarial temoin; do
  echo "# $c"; montre "généralisation $c" -iE "suggestion|refus|médian|bande|plafond" 6 non redact run_generalisation_bench.dart "../../bench/qi/corpus_qi_$c.jsonl" || true
done
echo "# lieu"; montre "généralisation du lieu" -iE "relu|F recalcul|bande recalcul" 0 non redact run_generalisation_lieu_bench.dart || true

echo "## dossiers (avec Dossier)"
produit "générateur dossiers" "$B/dossiers/corpus_dossiers_realiste.jsonl" python3 "$B/generate_corpus_dossiers.py" --n 400 --seed 42 --out-dir "$B/dossiers" || true
for c in realiste adversarial temoin; do
  produit "variantes de casse (dossiers $c)" "$B/dossiers/corpus_dossiers_${c}_minuscules.jsonl" python3 "$B/variantes_casse.py" "$B/dossiers/corpus_dossiers_$c.jsonl" || true
done
for c in realiste adversarial temoin realiste_minuscules realiste_majuscules realiste_mixte adversarial_minuscules adversarial_mixte temoin_mixte; do
  echo "# $c"
  if produit "dossiers $c, Ecluse.redact" "$B/dossiers/pred_$c.jsonl" redact run_dossiers_bench.dart --dossier "../../bench/dossiers/corpus_dossiers_$c.jsonl" "../../bench/dossiers/pred_$c.jsonl"; then
    # « ^    nom » : la ligne de cohérence des noms, annoncée par ETAT.md et que
    # l'ancien filtre (« coh ») ne laissait pas passer.
    montre "dossiers $c, score" -iE "coh|collision|fusion|restaur|non d|^    nom " 6 non python3 "$B/score_dossiers.py" --corpus "$B/dossiers/corpus_dossiers_$c.jsonl" --pred "$B/dossiers/pred_$c.jsonl" || true
  fi
done

# Patronyme seul hors civilité (P2-218) : sur le corpus de dossiers réaliste
# entier, noms restés en clair (civilité exclue) en appel Ecluse.redact
# document par document, puis en session de dossier (`--dossier`, déjà produite
# plus haut), par tournure. Puis un témoin de 400 phrases sans nom de personne
# sur les mêmes tournures : chaque masquage y est un masquage en trop (pas une
# fuite). Chemin mesuré : Ecluse.redact (ce que reçoit le LLM). Mesure seule.
echo "## patronyme seul hors civilité (P2-218) : Ecluse.redact (chemin du produit)"
if produit "patronyme seul, document par document" "$B/dossiers/pred_realiste_document.jsonl" redact run_dossiers_bench.dart ../../bench/dossiers/corpus_dossiers_realiste.jsonl ../../bench/dossiers/pred_realiste_document.jsonl; then
  montre "patronyme seul, score" -E "^noms hors civilité|^  tournure=" 0 non dans_B python3 score_patronyme_seul.py --corpus dossiers/corpus_dossiers_realiste.jsonl --pred-document dossiers/pred_realiste_document.jsonl --pred-session dossiers/pred_realiste.jsonl || true
fi
if produit "tournures sans nom, générateur" "$B/flou/corpus_tournures_sans_nom.jsonl" python3 "$B/generate_corpus_tournures_sans_nom.py" --n 400 --seed 42 --out "$B/flou/corpus_tournures_sans_nom.jsonl"; then
  if produit "tournures sans nom, Ecluse.redact" "$B/flou/pred_tournures_sans_nom.jsonl" redact run_redact_bench.dart ../../bench/flou/corpus_tournures_sans_nom.jsonl ../../bench/flou/pred_tournures_sans_nom.jsonl; then
    montre "tournures sans nom, score" -E "^tournures sans nom :|^  (tournure|genre)=|^  types sur" 0 non dans_B python3 score_tournures_sans_nom.py --corpus flou/corpus_tournures_sans_nom.jsonl --pred flou/pred_tournures_sans_nom.jsonl || true
  fi
fi

# Liste de patronymes fournie par l'application (P2-243, protocole de la § 7 de
# agent/specs/P2-219.md). Chemin mesuré : Ecluse.redact avec
# `Dossier(patronymesConnus: …)` (ce que reçoit le LLM), rien du moteur seul.
# Quatre états : sans liste, liste exacte (les personnes du dossier), liste
# large (toutes les personnes du corpus, des patronymes qui sont des mots
# courants et 10 000 noms tirés au hasard) et liste large privée des personnes
# du dossier. Tout est synthétique (graine 42). Le temps n'est pas rejoué ici :
# `bin/run_patronymes_cout.dart`, à la main (chiffres non déterministes).
echo "## liste de patronymes de l'application (P2-243) : Ecluse.redact (chemin du produit)"
LP="$B/patronymes"
liste() { # ÉTIQUETTE CORPUS LISTE.json SORTIE : un dossier par clé du corpus
  local etiquette=$1 corpus=$2 liste=$3 sortie=$4
  produit "liste $etiquette" "$sortie" redact run_dossiers_bench.dart "--patronymes=$liste" "$corpus" "$sortie"
}
if produit "corpus patronymes (b, c, leurres)" "$LP/corpus_patronymes_leurres.jsonl" python3 "$B/generate_corpus_patronymes.py" --n 400 --seed 42 --out-dir "$LP" \
  && produit "listes, première mention (b)" "$LP/liste_b/patronymes_large.json" python3 "$B/export_patronymes_dossiers.py" --corpus "$LP/corpus_patronymes_b.jsonl" --out-dir "$LP/liste_b" \
  && produit "listes, leurres isolés" "$LP/liste_leurres/isoles/patronymes_large.json" python3 "$B/export_patronymes_dossiers.py" --corpus "$LP/corpus_patronymes_leurres.jsonl" --out-dir "$LP/liste_leurres" --leurres-isoles "$LP/corpus_patronymes_leurres_isoles.jsonl" \
  && produit "listes, corpus de dossiers réaliste" "$B/dossiers/patronymes_large.json" python3 "$B/export_patronymes_dossiers.py" --corpus "$B/dossiers/corpus_dossiers_realiste.jsonl" --out-dir "$B/dossiers"; then
  echo "# patronyme seul en première mention (corpus b, 400 mentions) : détecté / annoté"
  for m in sans_liste exacte large sans; do
    echo "# b, liste $m"
    if [ "$m" = sans_liste ]; then
      ok=0; produit "liste b $m" "$LP/pred_b_$m.jsonl" redact run_dossiers_bench.dart --dossier $LP/corpus_patronymes_b.jsonl "$LP/pred_b_$m.jsonl" && ok=1
    else
      ok=0; liste "b $m" $LP/corpus_patronymes_b.jsonl "$LP/liste_b/patronymes_$m.json" "$LP/pred_b_$m.jsonl" && ok=1
    fi
    [ "$ok" = 1 ] && { montre "liste b $m, score" -E "^  b_(debut|milieu) " 2 non dans_B python3 score_patronymes.py --corpus patronymes/corpus_patronymes_b.jsonl --pred "patronymes/pred_b_$m.jsonl" || true; }
  done
  echo "# leurres (un mot courant fourni comme nom, document seul dans son dossier)"
  for m in sans_liste exacte large sans; do
    ok=0
    if [ "$m" = sans_liste ]; then
      produit "liste leurres $m" "$LP/pred_leurres_$m.jsonl" redact run_dossiers_bench.dart --dossier $LP/corpus_patronymes_leurres_isoles.jsonl "$LP/pred_leurres_$m.jsonl" && ok=1
    else
      liste "leurres $m" $LP/corpus_patronymes_leurres_isoles.jsonl "$LP/liste_leurres/isoles/patronymes_$m.json" "$LP/pred_leurres_$m.jsonl" && ok=1
    fi
    [ "$ok" = 1 ] && { montre "liste leurres $m, score" -E . 0 non python3 "$B/score_liste_temoin.py" "leurres, liste $m" "$LP/corpus_patronymes_leurres_isoles.jsonl" "$LP/pred_leurres_$m.jsonl" || true; }
  done
  echo "# corpus de dossiers réaliste (116 patronymes seuls) : manqués en session"
  for m in exacte large sans; do
    if liste "réaliste $m" $B/dossiers/corpus_dossiers_realiste.jsonl "$B/dossiers/patronymes_$m.json" "$B/dossiers/pred_realiste_liste_$m.jsonl"; then
      montre "liste réaliste $m, score" -E "^noms hors civilité, patronyme seul" 1 non dans_B python3 score_patronyme_seul.py --corpus dossiers/corpus_dossiers_realiste.jsonl --pred-document dossiers/pred_realiste_document.jsonl --pred-session "dossiers/pred_realiste_liste_$m.jsonl" | sed "s/^/  liste $m : /" || true
    fi
  done
  echo "# témoin sans nom de personne (tournures, 400 documents) : liste large de 10 042 noms"
  if produit "témoin sans nom, sans liste, en dossier" "$B/flou/pred_tsn_dossier_sans.jsonl" redact run_dossiers_bench.dart --dossier $B/flou/corpus_tournures_sans_nom.jsonl $B/flou/pred_tsn_dossier_sans.jsonl; then
    montre "témoin sans liste" -E . 0 non python3 "$B/score_liste_temoin.py" "témoin, sans liste" "$B/flou/corpus_tournures_sans_nom.jsonl" "$B/flou/pred_tsn_dossier_sans.jsonl" || true
  fi
  if liste "témoin large" $B/flou/corpus_tournures_sans_nom.jsonl "$B/dossiers/patronymes_large.json" $B/flou/pred_tsn_liste_large.jsonl; then
    montre "témoin liste large" -E . 0 non python3 "$B/score_liste_temoin.py" "témoin, liste large" "$B/flou/corpus_tournures_sans_nom.jsonl" "$B/flou/pred_tsn_liste_large.jsonl" || true
  fi
fi

# Témoin élargi des tournures de personne (P2-226) : cinq familles de mots
# (rôles et parenté, organismes et marques, noms communs à majuscule, puis deux
# familles de patronymes annotés) dans les quatre tournures de P2-220, chaque
# mot une fois par tournure. Chemin mesuré : Ecluse.redact, document par
# document. Familles sans personne : masquage en trop ; patronymes : en clair,
# une fuite. Mesure seule.
echo "## tournures de personne, témoin élargi (P2-226) : Ecluse.redact (chemin du produit)"
if produit "tournures de personne, générateur" "$B/flou/corpus_tournures_personne.jsonl" python3 "$B/generate_corpus_tournures_personne.py" --seed 42 --out "$B/flou/corpus_tournures_personne.jsonl"; then
  if produit "tournures de personne, Ecluse.redact" "$B/flou/pred_tournures_personne.jsonl" redact run_redact_bench.dart ../../bench/flou/corpus_tournures_personne.jsonl ../../bench/flou/pred_tournures_personne.jsonl; then
    montre "tournures de personne, score" -E "^tournures de personne :|^  famille=|^    tournure=|^  types sur" 0 non dans_B python3 score_tournures_personne.py --corpus flou/corpus_tournures_personne.jsonl --pred flou/pred_tournures_personne.jsonl || true
  fi
fi

# Communes de 10 000 à 100 000 habitants derrière les tournures de personne
# (P2-238) : lieux tirés du référentiel versionné, 20 par tranche (10-30k,
# 30-50k, 50-100k), chacun dans les quatre tournures de P2-220. Aucune
# personne : un lieu masqué est un masquage en trop. Chemin mesuré :
# Ecluse.redact, document par document. Mesure seule (seuil de `main` :
# 10 000 habitants derrière « à la demande de »).
echo "## communes moyennes derrière les tournures de personne (P2-238) : Ecluse.redact (chemin du produit)"
if produit "communes moyennes, générateur" "$B/flou/corpus_tournures_communes_moyennes.jsonl" python3 "$B/generate_corpus_tournures_communes_moyennes.py" --seed 42 --out "$B/flou/corpus_tournures_communes_moyennes.jsonl"; then
  if produit "communes moyennes, Ecluse.redact" "$B/flou/pred_tournures_communes_moyennes.jsonl" redact run_redact_bench.dart ../../bench/flou/corpus_tournures_communes_moyennes.jsonl ../../bench/flou/pred_tournures_communes_moyennes.jsonl; then
    montre "communes moyennes, score" -E "^communes moyennes :|^  (tranche|tournure|tranche_tournure)=" 0 non dans_B python3 score_tournures_communes_moyennes.py --corpus flou/corpus_tournures_communes_moyennes.jsonl --pred flou/pred_tournures_communes_moyennes.jsonl || true
  fi
fi

# Sonde « prénom + verbe conjugué » (P2-235, P2-240) : 10 prénoms × 40 verbes
# courants (famille courants) et 20 verbes hors de la liste fermée du
# détecteur (famille reserve), plus 68 verbes de l'écrit soignant écrits avant
# l'extension de la liste (famille reserve2, P2-242). Un verbe masqué est un masquage en trop ; un
# prénom en clair serait une fuite. Chemin mesuré : Ecluse.redact, document par
# document.
echo "## prénom + verbe conjugué (P2-240) : Ecluse.redact (chemin du produit)"
if produit "prénom + verbe, générateur" "$B/flou/corpus_prenom_verbe.jsonl" python3 "$B/generate_corpus_prenom_verbe.py" --seed 42 --out "$B/flou/corpus_prenom_verbe.jsonl"; then
  if produit "prénom + verbe, Ecluse.redact" "$B/flou/pred_prenom_verbe.jsonl" redact run_redact_bench.dart ../../bench/flou/corpus_prenom_verbe.jsonl ../../bench/flou/pred_prenom_verbe.jsonl; then
    montre "prénom + verbe, score" -E "^prénom \+ verbe :|^  famille=" 0 non dans_B python3 score_prenom_verbe.py --corpus flou/corpus_prenom_verbe.jsonl --pred flou/pred_prenom_verbe.jsonl || true
  fi
fi

echo "## pathologies"
produit "générateur pathologies" "$B/patho/corpus_pathologies_indices.jsonl" python3 "$B/generate_corpus_pathologies.py" --n 300 --seed 42 --out-dir "$B/patho" || true
patho_rattachees() { reid run_pathologies_bench.dart "../../bench/patho/corpus_pathologies_$1.jsonl" "../../bench/patho/corpus_pathologies_temoin.jsonl" | sed -n '/rattachées/,$p'; }
for c in indices variantes; do
  echo "# $c"; montre "pathologies $c" -E "indices :|témoin :" 0 non patho_rattachees "$c" || true
done
echo "# formes_libres"; montre "pathologies formes_libres" -E "TOTAL" 0 non reid run_formes_libres.dart ../../bench/patho/corpus_pathologies_formes_libres.jsonl || true
echo "# maladies rares masquées (P2-143)"; montre "maladies rares" -E "indices :|temoin :|échantillon" 0 non redact run_maladies_rares_bench.dart ../../bench/patho || true

echo "## témoin nombres à cinq chiffres (P2-167) : Ecluse.redact (chemin du produit), aucune adresse annotée"
if produit "témoin cinq chiffres, générateur" "$B/flou/corpus_flou_cinq_chiffres.jsonl" python3 "$B/generate_corpus_cinq_chiffres.py" --n 400 --seed 42 --out "$B/flou/corpus_flou_cinq_chiffres.jsonl"; then
  montre "témoin cinq chiffres, Ecluse.redact" -E . 0 non redact run_cinq_chiffres_bench.dart ../../bench/flou/corpus_flou_cinq_chiffres.jsonl || true
fi

# Témoin « cinq chiffres + LE/LA/LES/L' + mots ordinaires » (P2-187), en
# capitales et en casse ordinaire : le coût (masquage en trop) de la
# correction « commune composée en LA, LE, LES, L' » de la branche capitales.
echo "## témoin déterminant après cinq chiffres (P2-187) : Ecluse.redact (chemin du produit), aucune adresse annotée"
if produit "témoin déterminant, générateur" "$B/flou/corpus_flou_determinant.jsonl" python3 "$B/generate_corpus_determinant.py" --n 400 --seed 42 --out "$B/flou/corpus_flou_determinant.jsonl"; then
  montre "témoin déterminant, Ecluse.redact" -E . 0 non redact run_cinq_chiffres_bench.dart ../../bench/flou/corpus_flou_determinant.jsonl || true
fi

# Code postal en tête de texte, de ligne ou de phrase (P2-177) : le pendant du
# témoin ci-dessus, avec des adresses annotées de la même forme. Une adresse
# en clair est une fuite. La règle candidate est simulée par le banc (elle
# n'est pas dans lib/) : ce qu'elle retirerait du témoin, ce qu'elle perdrait.
echo "## code postal en tête (P2-177) : Ecluse.redact (chemin du produit), adresses à ne pas perdre"
if produit "code postal en tête, générateur" "$B/flou/corpus_flou_cp_tete.jsonl" python3 "$B/generate_corpus_cp_tete.py" --n 432 --seed 42 --out "$B/flou/corpus_flou_cp_tete.jsonl"; then
  montre "code postal en tête, Ecluse.redact" -E . 0 non redact run_cp_tete_bench.dart ../../bench/flou/corpus_flou_cp_tete.jsonl --regle-candidate ../../bench/flou/corpus_flou_cinq_chiffres.jsonl || true
fi

# Balayage des communes (P2-178, mesure de départ ; P2-180, correction
# « œ »/faux titre). Les 34 875 communes du référentiel, une fois par
# écriture (libelle, postale, libelle_espaces, capitales_tirets), avec
# « CEDEX n ». Une commune en partie en clair est un défaut (chiffre de
# départ de la tâche de correction suivante, tant qu'il n'est pas nul).
echo "## communes : nom en partie en clair après CEDEX (P2-178, P2-180) : Ecluse.redact (chemin du produit)"
if produit "communes balayage, générateur" "$B/flou/corpus_cedex_balayage.jsonl" python3 "$B/generate_corpus_cedex.py" --balayage --communes "$R/packages/ecluse_reference/assets/geo_communes.csv.gz" --out "$B/flou/corpus_cedex_balayage.jsonl"; then
  if produit "communes balayage, Ecluse.redact" "$B/flou/pred_cedex_balayage.jsonl" redact run_redact_bench.dart ../../bench/flou/corpus_cedex_balayage.jsonl ../../bench/flou/pred_cedex_balayage.jsonl; then
    montre "communes balayage, score" -E "^cedex commune longue :|^  ecriture=" 0 non dans_B python3 score_cedex.py --corpus flou/corpus_cedex_balayage.jsonl --pred flou/pred_cedex_balayage.jsonl || true
  fi
fi

# Témoin de sur-masquage (P2-181) : une adresse « code postal + commune »
# suivie, sur la même ligne, de mots ordinaires qui n'en font pas partie
# (capitales, mots à majuscule, « et », « à »…). La suite masquée est de la
# lisibilité perdue, pas une fuite ; l'adresse en clair, elle, doit rester à 0.
echo "## commune suivie de mots ordinaires (P2-181) : Ecluse.redact (chemin du produit), suite à ne pas masquer"
if produit "commune suivie, générateur" "$B/flou/corpus_flou_commune_suivie.jsonl" python3 "$B/generate_corpus_commune_suivie.py" --n 480 --seed 42 --out "$B/flou/corpus_flou_commune_suivie.jsonl"; then
  if produit "commune suivie, Ecluse.redact" "$B/flou/pred_commune_suivie.jsonl" redact run_redact_bench.dart ../../bench/flou/corpus_flou_commune_suivie.jsonl ../../bench/flou/pred_commune_suivie.jsonl; then
    montre "commune suivie, score" -E "^commune suivie :|^  (famille|ecriture)=" 0 non dans_B python3 score_commune_suivie.py --corpus flou/corpus_flou_commune_suivie.jsonl --pred flou/pred_commune_suivie.jsonl || true
  fi
fi
# Même balayage, document tout en capitales (P2-183, P2-185) : texte « sans
# aucune minuscule », branche `capitales` d'`AdresseDetector`. Chiffre de départ
# de P2-185 ; la cause « déterminant initial » (« 01097 LA BOISSE ») doit y
# baisser. Le texte sans majuscule (autre branche) n'est pas rejoué ici.
echo "## communes en capitales : nom en partie en clair après CEDEX (P2-183, P2-185) : Ecluse.redact (chemin du produit)"
if [ -s "$B/flou/corpus_cedex_balayage.jsonl" ] \
   && produit "communes balayage capitales, variantes" "$B/flou/corpus_cedex_balayage_majuscules.jsonl" python3 "$B/variantes_casse.py" "$B/flou/corpus_cedex_balayage.jsonl"; then
  if produit "communes balayage capitales, Ecluse.redact" "$B/flou/pred_cedex_balayage_majuscules.jsonl" redact run_redact_bench.dart ../../bench/flou/corpus_cedex_balayage_majuscules.jsonl ../../bench/flou/pred_cedex_balayage_majuscules.jsonl; then
    montre "communes balayage capitales, score" -E "^cedex commune longue :|^  cedex=|^  cause=" 0 non dans_B python3 score_cedex.py --corpus flou/corpus_cedex_balayage_majuscules.jsonl --pred flou/pred_cedex_balayage_majuscules.jsonl || true
  fi
else
  echec "communes balayage capitales : corpus ordinaire absent ou variantes non produites"
fi

# Même balayage en capitales SANS « CEDEX » (P2-200) : exposition du
# référentiel quand rien n'annonce une adresse de courrier d'entreprise. Mêmes
# causes que la version avec CEDEX ; la règle du mot neutre y est entière.
echo "## communes en capitales sans CEDEX : nom en partie en clair (P2-200) : Ecluse.redact (chemin du produit)"
if produit "communes balayage sans CEDEX, générateur" "$B/flou/corpus_cedex_balayage_sans.jsonl" python3 "$B/generate_corpus_cedex.py" --balayage --cedex sans --communes "$R/packages/ecluse_reference/assets/geo_communes.csv.gz" --out "$B/flou/corpus_cedex_balayage_sans.jsonl" \
   && produit "communes balayage sans CEDEX, variantes" "$B/flou/corpus_cedex_balayage_sans_majuscules.jsonl" python3 "$B/variantes_casse.py" "$B/flou/corpus_cedex_balayage_sans.jsonl"; then
  if produit "communes balayage sans CEDEX, Ecluse.redact" "$B/flou/pred_cedex_balayage_sans_majuscules.jsonl" redact run_redact_bench.dart ../../bench/flou/corpus_cedex_balayage_sans_majuscules.jsonl ../../bench/flou/pred_cedex_balayage_sans_majuscules.jsonl; then
    montre "communes balayage sans CEDEX, score" -E "^cedex commune longue :|^  cedex=|^  cause=" 0 non dans_B python3 score_cedex.py --corpus flou/corpus_cedex_balayage_sans_majuscules.jsonl --pred flou/pred_cedex_balayage_sans_majuscules.jsonl || true
  fi
else
  echec "communes balayage sans CEDEX : corpus absent ou variantes non produites"
fi

# Témoin de faux positifs « cinq chiffres + mot neutre (+ parenthèse, tiret) +
# CEDEX n » (P2-200), aucune adresse annotée : ce que coûterait la levée de la
# règle du mot neutre devant CEDEX (P2-201). Chiffre avant toute correction.
echo "## témoin mot neutre devant CEDEX (P2-200) : Ecluse.redact (chemin du produit), aucune adresse annotée"
if produit "témoin neutre CEDEX, générateur" "$B/flou/corpus_flou_neutre_cedex.jsonl" python3 "$B/generate_corpus_neutre_cedex.py" --n 400 --seed 42 --out "$B/flou/corpus_flou_neutre_cedex.jsonl"; then
  montre "témoin neutre CEDEX, Ecluse.redact" -E . 0 non redact run_cinq_chiffres_bench.dart ../../bench/flou/corpus_flou_neutre_cedex.jsonl || true
fi

# Communes en capitales sans « CEDEX » : ventilation en cinq formes et coût de
# deux règles candidates (P2-206). Mesure seulement : les règles « nom exact du
# référentiel » et « fin de ligne » sont simulées par `regles_candidates_
# communes.py` en ajoutant leur étendue aux détections de `Ecluse.redact`, rien
# n'est dans lib/. Chemin mesuré : Ecluse.redact (ce que reçoit le LLM).
echo "## communes en capitales sans CEDEX : formes et règles candidates (P2-206) : Ecluse.redact (chemin du produit), règles simulées hors lib/"
if [ -s "$B/flou/pred_cedex_balayage_sans_majuscules.jsonl" ]; then
  montre "formes sans CEDEX" -E "^sans CEDEX :|^  forme " 0 non dans_B python3 classe_communes_capitales.py --sans || true
  montre "règles candidates, balayage sans CEDEX" -E "^balayage sans CEDEX|^  règle=|^  forme E" 0 non dans_B python3 regles_candidates_communes.py balayage --corpus flou/corpus_cedex_balayage_sans_majuscules.jsonl --pred flou/pred_cedex_balayage_sans_majuscules.jsonl || true
else
  echec "formes sans CEDEX : prédictions du balayage sans CEDEX absentes"
fi
echo "# coût sur le témoin commune suivie (P2-181) : règle appliquée à toute ligne, puis aux seuls textes en capitales"
if [ -s "$B/flou/pred_commune_suivie.jsonl" ] \
   && produit "commune suivie capitales, variantes" "$B/flou/corpus_flou_commune_suivie_majuscules.jsonl" python3 "$B/variantes_casse.py" "$B/flou/corpus_flou_commune_suivie.jsonl" \
   && produit "commune suivie capitales, Ecluse.redact" "$B/flou/pred_commune_suivie_majuscules.jsonl" redact run_redact_bench.dart ../../bench/flou/corpus_flou_commune_suivie_majuscules.jsonl ../../bench/flou/pred_commune_suivie_majuscules.jsonl; then
  montre "règles candidates, témoin suivie (toute ligne)" -E "^commune suivie, règles|^  règle=" 0 non dans_B python3 regles_candidates_communes.py suivie --corpus flou/corpus_flou_commune_suivie.jsonl --pred flou/pred_commune_suivie.jsonl || true
  montre "règles candidates, témoin suivie (capitales)" -E "^commune suivie, règles|^  règle=" 0 non dans_B python3 regles_candidates_communes.py suivie --casse capitales --corpus flou/corpus_flou_commune_suivie_majuscules.jsonl --pred flou/pred_commune_suivie_majuscules.jsonl || true
else
  echec "règles candidates, témoin suivie : corpus ou prédictions absents"
fi
echo "# coût sur les témoins sans adresse annotée : noms de communes de forme neutre (P2-206), puis témoins P2-167 et P2-187"
echo "# témoin commune neutre (P2-206)"
if produit "témoin commune neutre, générateur" "$B/flou/corpus_flou_commune_neutre.jsonl" dans_B python3 generate_corpus_commune_neutre.py --n 400 --seed 42 --out flou/corpus_flou_commune_neutre.jsonl; then
  if produit "témoin commune neutre, Ecluse.redact" "$B/flou/pred_commune_neutre.jsonl" redact run_redact_bench.dart ../../bench/flou/corpus_flou_commune_neutre.jsonl ../../bench/flou/pred_commune_neutre.jsonl; then
    montre "règles candidates, témoin commune neutre" -E "^témoin sans adresse annotée|^  casse=" 0 non dans_B python3 regles_candidates_communes.py neutre --corpus flou/corpus_flou_commune_neutre.jsonl --pred flou/pred_commune_neutre.jsonl || true
  fi
fi
for t in cinq_chiffres determinant; do
  echo "# témoin $t (P2-167, P2-187)"
  if [ -s "$B/flou/corpus_flou_$t.jsonl" ] && produit "règles candidates, témoin $t, Ecluse.redact" "$B/flou/pred_$t.jsonl" redact run_redact_bench.dart ../../bench/flou/corpus_flou_$t.jsonl ../../bench/flou/pred_$t.jsonl; then
    montre "règles candidates, témoin $t" -E "^témoin sans adresse annotée|^  casse=" 0 non dans_B python3 regles_candidates_communes.py neutre --corpus flou/corpus_flou_$t.jsonl --pred flou/pred_$t.jsonl || true
  else
    echec "règles candidates, témoin $t : corpus ou prédictions absents"
  fi
done
# Commune dont le nom contient un mot de voie (P2-213) : les 52 communes du
# référentiel dont la forme postale porte un type de voie du détecteur
# (« GRAFFIGNY CHEMIN », « LA CHAUSSEE TIRANCOURT », « RUE »), lus dans
# `adresse_detector.dart`. Six cases écriture x casse, avec et sans CEDEX,
# suivies ou non d'une ligne « code postal + mot » ou d'une seconde adresse,
# derrière ou non une vraie voie (contrôle). Chemin mesuré : Ecluse.redact. Une
# adresse en partie en clair est une fuite ; « début en clair » (code postal
# ou premier mot du nom) est la signature du défaut de P2-213, « fin du nom
# seule » celle des communes de plus de quatre mots sans CEDEX (P2-205).
echo "## commune à mot de voie (P2-213) : Ecluse.redact (chemin du produit), adresses en partie en clair"
if produit "commune à mot de voie, générateur" "$B/flou/corpus_commune_voie.jsonl" python3 "$B/generate_corpus_commune_voie.py" --seed 42 --communes "$R/packages/ecluse_reference/assets/geo_communes.csv.gz" --detecteur "$R/packages/ecluse_redact/lib/src/heuristics/adresse_detector.dart" --out "$B/flou/corpus_commune_voie.jsonl"; then
  if produit "commune à mot de voie, Ecluse.redact" "$B/flou/pred_commune_voie.jsonl" redact run_redact_bench.dart ../../bench/flou/corpus_commune_voie.jsonl ../../bench/flou/pred_commune_voie.jsonl; then
    montre "commune à mot de voie, score" -E "^commune à mot de voie :|^  (casse|ecriture|cedex|suite|voie|mot de voie)=|^  en clair :|^  début en clair|^  ligne « code postal" 0 non dans_B python3 score_commune_voie.py --corpus flou/corpus_commune_voie.jsonl --pred flou/pred_commune_voie.jsonl || true
  fi
fi

# Écritures de communes hors référentiel (P2-244, mesure de `agent/specs/P2-215.md`) :
# la règle « nom exact » lit « ST »/« STE » comme « SAINT »/« SAINTE » et compare
# les noms collés. Une adresse par commune et par écriture (261 communes des
# formes A, C et D), tout en capitales, sans CEDEX. Colonne `Ecluse.redact seul` :
# adresses en partie en clair avec le code livré ; les colonnes de règles
# (exact, normalise, distance1) sont des simulations hors lib/ (union des
# détections et de l'étendue simulée, `resolveOverlaps` non rejoué).
echo "## communes en capitales hors référentiel : « ST », séparateurs collés, fautes (P2-244) : Ecluse.redact (chemin du produit), règles simulées hors lib/"
if produit "écritures hors référentiel, générateur" "$B/flou/corpus_ecritures_hors_referentiel.jsonl" python3 "$B/ecritures_hors_referentiel.py" genere --seed 42 --out "$B/flou/corpus_ecritures_hors_referentiel.jsonl"; then
  if produit "écritures hors référentiel, Ecluse.redact" "$B/flou/pred_ecritures_hors_referentiel.jsonl" redact run_redact_bench.dart ../../bench/flou/corpus_ecritures_hors_referentiel.jsonl ../../bench/flou/pred_ecritures_hors_referentiel.jsonl; then
    montre "écritures hors référentiel, couverture" -E "^écritures hors référentiel :|^# table|^  (variante=|écritures hors référentiel)" 0 non dans_B python3 ecritures_hors_referentiel.py couverture --corpus flou/corpus_ecritures_hors_referentiel.jsonl --pred flou/pred_ecritures_hors_referentiel.jsonl || true
  fi
fi

# Courriers synthétiques en capitales (P2-210) : la fréquence de « cinq chiffres
# + mot neutre + CEDEX » dans des courriers entiers (titres, références,
# montants, nombres de dossiers, adresses de retour), que le témoin de P2-200
# (pire cas, une phrase par forme) ne dit pas. Le motif de construction et ses
# poids (une hypothèse, pas une observation) sont dans le générateur. Chemin
# mesuré : Ecluse.redact. Un masquage en trop est de la lisibilité perdue ; une
# adresse annotée en partie en clair est une fuite.
echo "## courriers en capitales (P2-210) : Ecluse.redact (chemin du produit), masquage en trop et adresses annotées"
if produit "courriers capitales, générateur" "$B/flou/corpus_courriers.jsonl" python3 "$B/generate_corpus_courriers.py" --n 400 --seed 42 --communes "$R/packages/ecluse_reference/assets/geo_communes.csv.gz" --out "$B/flou/corpus_courriers.jsonl"; then
  if produit "courriers capitales, Ecluse.redact" "$B/flou/pred_courriers.jsonl" redact run_redact_bench.dart ../../bench/flou/corpus_courriers.jsonl ../../bench/flou/pred_courriers.jsonl; then
    montre "courriers capitales, score" -E "^courriers :|^  masquage en trop|^  famille=|^  mot après un nombre=|^  types en trop" 0 non dans_B python3 score_courriers.py --corpus flou/corpus_courriers.jsonl --pred flou/pred_courriers.jsonl || true
  fi
fi

# SIREN pris pour un FINESS (P2-223) : même structure, même clé de Luhn. Corpus
# v3 entier (nombres de neuf chiffres à clé valide non annotés), témoin de 400
# documents à SIREN (avec et sans le mot « SIREN » à proximité) et son pendant
# de 400 vrais FINESS ; options chiffrées HORS lib/ (filtres appliqués aux
# prédictions), avec le nombre de vrais FINESS qu'elles feraient partir en
# clair. Chemin mesuré : Ecluse.redact (ce que reçoit le LLM). Mesure seule.
echo "## SIREN masqués comme FINESS (P2-223) : Ecluse.redact (chemin du produit)"
if produit "SIREN, générateur" "$B/flou/corpus_siren.jsonl" python3 "$B/generate_corpus_siren.py" --n 400 --seed 42 --out-dir "$B/flou" \
   && produit "SIREN, v3 Ecluse.redact" "$B/flou/pred_siren_v3.jsonl" redact run_redact_bench.dart --confiance ../../bench/corpus.jsonl ../../bench/flou/pred_siren_v3.jsonl \
   && produit "SIREN, témoin Ecluse.redact" "$B/flou/pred_siren.jsonl" redact run_redact_bench.dart --confiance ../../bench/flou/corpus_siren.jsonl ../../bench/flou/pred_siren.jsonl \
   && produit "SIREN, pendant FINESS Ecluse.redact" "$B/flou/pred_finess_pendant.jsonl" redact run_redact_bench.dart --confiance ../../bench/flou/corpus_finess_pendant.jsonl ../../bench/flou/pred_finess_pendant.jsonl; then
  montre "SIREN, score" -E "^SIREN masqués comme FINESS|^vrais FINESS en clair|^  (témoin|option)" 0 non dans_B python3 score_siren_finess.py --v3 corpus.jsonl flou/pred_siren_v3.jsonl --siren flou/corpus_siren.jsonl flou/pred_siren.jsonl --finess flou/corpus_finess_pendant.jsonl flou/pred_finess_pendant.jsonl || true
fi

# Mots neutres, un mot à la fois (P2-211) : tous les mots de `mots_neutres.dart`
# (lus dans le fichier Dart, aucune liste recopiée), 400 phrases « nombre à cinq
# chiffres + mot » par mot, forme accentuée et forme sans accent quand elle
# diffère, capitales et casse ordinaire. Aucune entité annotée : un nombre sous
# une détection `adresse` est un masquage en trop (lisibilité perdue, pas une
# fuite). Chemin mesuré : Ecluse.redact. Les déterminants (« le », « la »,
# « les », « l ») suivis d'un nom en capitales sont le coût connu de P2-187.
echo "## mots neutres, un mot à la fois (P2-211) : Ecluse.redact (chemin du produit), nombres masqués en adresse"
if produit "mots neutres, générateur" "$B/flou/corpus_flou_mots_neutres.jsonl" python3 "$B/generate_corpus_mots_neutres.py" --n 400 --seed 42 --mots "$R/packages/ecluse_redact/lib/src/heuristics/mots_neutres.dart" --out "$B/flou/corpus_flou_mots_neutres.jsonl"; then
  if produit "mots neutres, Ecluse.redact" "$B/flou/pred_mots_neutres.jsonl" redact run_redact_bench.dart ../../bench/flou/corpus_flou_mots_neutres.jsonl ../../bench/flou/pred_mots_neutres.jsonl; then
    montre "mots neutres, score" -E "^mots neutres :|^  (casse|forme|position|suite|majuscules)=|^  mot=|^  types sur le nombre" 0 non dans_B python3 score_mots_neutres.py --corpus flou/corpus_flou_mots_neutres.jsonl --pred flou/pred_mots_neutres.jsonl || true
  fi
fi

# Identifiant suivi d'une date, d'un âge ou d'un nombre (P2-174) : 4 types x
# 4 familles x 3 séparateurs x 100 documents. Un identifiant non couvert est
# une fuite ; un type faux ou une suite avalée abîme le texte sans fuite.
echo "## identifiant suivi d'un nombre (P2-174) : Ecluse.redact (chemin du produit)"
produit "générateur identifiant suivi" "$B/flou/corpus_identifiant_suivi.jsonl" dans_B python3 generate_corpus_identifiant_suivi.py --n 100 --seed 42 --out flou/corpus_identifiant_suivi.jsonl || true
if produit "identifiant suivi, Ecluse.redact" "$B/flou/pred_identifiant_suivi.jsonl" redact run_redact_bench.dart ../../bench/flou/corpus_identifiant_suivi.jsonl ../../bench/flou/pred_identifiant_suivi.jsonl; then
  montre "identifiant suivi, score" -E "^identifiant suivi|type_id=|separateur=|^  défaut" 0 non dans_B python3 score_identifiant_suivi.py --corpus flou/corpus_identifiant_suivi.jsonl --pred flou/pred_identifiant_suivi.jsonl || true
fi

# Identifiant derrière un libellé fort (P2-194) : la voie de P2-188 (clé
# fausse) et de P2-191 (O pour 0, l ou I pour 1, ligne vide), que seuls des
# tests unitaires mesuraient. 6 libellés x 6 variantes x 50 positifs, plus des
# témoins négatifs (libellé sans identifiant, nombre sans libellé). Chemin
# mesuré : Ecluse.redact. Un positif en clair est une fuite ; le plafond par
# case (zéro, sauf défaut connu) est vérifié par `verifie_etat.py`.
echo "## identifiant derrière un libellé fort (P2-194) : Ecluse.redact (chemin du produit)"
if produit "libellé fort, générateur" "$B/flou/corpus_libelle_fort.jsonl" dans_B python3 generate_corpus_libelle_fort.py --n 50 --seed 42 --out flou/corpus_libelle_fort.jsonl; then
  if produit "libellé fort, Ecluse.redact" "$B/flou/pred_libelle_fort.jsonl" redact run_redact_bench.dart --confiance ../../bench/flou/corpus_libelle_fort.jsonl ../../bench/flou/pred_libelle_fort.jsonl; then
    montre "libellé fort, score" -E "^libellé fort|^  (variante|libellé)=|^  .+ x [a-z_]+ :|^  témoin négatif|^confiance des masquages|^  confiance |^  avertissement à vérifier|^  à vérifier variante=|^  incohérence confiance|^  exception P2-204" 0 non dans_B python3 score_libelle_fort.py --corpus flou/corpus_libelle_fort.jsonl --pred flou/pred_libelle_fort.jsonl || true
  fi
fi

echo "## mise en page (P2-153) : textes recoupés aux espaces, largeur 60 puis 90"
# Un refus explicite (tableau ambigu) n'envoie rien : il est compté à part et
# retiré du corpus noté ; la fuite se lit sur les documents traités.
for w in 60 90; do
  for c in realiste adversarial temoin; do
    produit "mise en page $c l$w, générateur" "$B/flou/corpus_flou_${c}_l$w.jsonl" python3 "$B/generate_corpus_mise_en_page.py" "$B/flou/corpus_flou_$c.jsonl" --largeur $w --out "$B/flou/corpus_flou_${c}_l$w.jsonl" || true
    if produit "mise en page $c l$w, Ecluse.redact" "$B/flou/etat_${c}_l$w.jsonl" redact run_redact_bench.dart "../../bench/flou/corpus_flou_${c}_l$w.jsonl" "../../bench/flou/etat_${c}_l$w.jsonl"; then
      refus=$(grep -c REFUS "$ERR" || true)
      python3 - "$B/flou/corpus_flou_${c}_l$w.jsonl" "$B/flou/etat_${c}_l$w.jsonl" <<'PY'
import json, sys
c, p = sys.argv[1], sys.argv[2]
refuses = {json.loads(l)["id"] for l in open(p) if json.loads(l).get("refuse")}
with open(c + ".traites", "w") as out:
    for l in open(c):
        if json.loads(l)["id"] not in refuses:
            out.write(l)
PY
      echo "# $c largeur $w : $refus refus"
      case "$c" in temoin) vide=oui ;; *) vide=non ;; esac
      montre "mise en page $c l$w, score" -E "^GLOBAL|^nom |^adresse |^etablissement " 0 "$vide" dans_B python3 score_flou.py --corpus "flou/corpus_flou_${c}_l$w.jsonl.traites" --pred "Ecluse=flou/etat_${c}_l$w.jsonl" || true
      # ETAT.md annonce « 0 prédiction » pour le témoin : la ligne sort ici.
      if [ "$c" = temoin ]; then predites "$B/flou/etat_${c}_l$w.jsonl"; fi
      # Entités coupées par un retour à la ligne (P2-173) : couvertes ou en
      # clair, par Ecluse.redact. Le témoin n'a aucune entité annotée.
      if [ "$c" != temoin ]; then
        montre "mise en page $c l$w, entités coupées" -E . 0 non python3 "$B/entites_coupees.py" --corpus "$B/flou/corpus_flou_${c}_l$w.jsonl.traites" --pred "$B/flou/etat_${c}_l$w.jsonl" || true
      fi
    fi
  done
  produit "mise en page structurel l$w, générateur" "$B/flou/structurel_l$w.jsonl" python3 "$B/generate_corpus_mise_en_page.py" "$B/corpus.jsonl" --largeur $w --out "$B/flou/structurel_l$w.jsonl" || true
  echo "# structurel largeur $w, moteur seul (ecluse_core)"
  if produit "structurel l$w, moteur seul" "$B/flou/pred_structurel_l$w.jsonl" bench_pkg run_ecluse.dart "../../bench/flou/structurel_l$w.jsonl" "../../bench/flou/pred_structurel_l$w.jsonl"; then
    montre "structurel l$w, score moteur seul" -E "^Ecluse +(nir|rpps|iban|finess|TOTAL)" 5 non dans_B python3 score.py --corpus "flou/structurel_l$w.jsonl" --pred "Ecluse=flou/pred_structurel_l$w.jsonl" || true
  fi
  # Détecteur isolé (P2-166) : NirDetector, RppsDetector, IbanFrDetector et
  # FinessDetector appelés directement, comme dans l'exemple du README
  # d'ecluse_core ; ni moteur, ni ecluse_redact.
  echo "# structurel largeur $w, détecteur isolé (appel direct des quatre détecteurs)"
  if produit "structurel l$w, détecteur isolé" "$B/flou/isole_structurel_l$w.jsonl" bench_pkg run_detecteur_isole.dart "../../bench/flou/structurel_l$w.jsonl" "../../bench/flou/isole_structurel_l$w.jsonl"; then
    montre "structurel l$w, rappel détecteur isolé" -E . 0 non python3 "$B/rappel_structurel.py" --corpus "$B/flou/structurel_l$w.jsonl" --pred "$B/flou/isole_structurel_l$w.jsonl" || true
  fi
  # Chemin du produit : Ecluse.redact neutralise la fin de ligne entre deux
  # groupes d'un identifiant (P2-38, P2-152) ; le moteur seul ne le fait pas.
  echo "# structurel largeur $w, Ecluse.redact (chemin du produit)"
  if produit "structurel l$w, Ecluse.redact" "$B/flou/redact_structurel_l$w.jsonl" redact run_redact_bench.dart "../../bench/flou/structurel_l$w.jsonl" "../../bench/flou/redact_structurel_l$w.jsonl"; then
    montre "structurel l$w, rappel Ecluse.redact" -E . 0 non python3 "$B/rappel_structurel.py" --corpus "$B/flou/structurel_l$w.jsonl" --pred "$B/flou/redact_structurel_l$w.jsonl" || true
  fi
done


# Collage hors du cœur (P2-166) : ce que détecteraient les détecteurs appelés
# seuls si la fin de ligne était recollée comme le fait ecluse_redact. Chemin
# mesuré : détecteurs isolés sur texte recollé par le banc ; rien n'est
# changé dans lib/. « à tort » = détection traversant une coupure qui ne
# recouvre aucun identifiant annoté.
echo "## collage de fin de ligne hors du cœur (P2-166)"
montre "collage, corpus recoupés" -E . 0 non bench_pkg run_collage_fp.dart ../../bench/flou/structurel_l60.jsonl ../../bench/flou/structurel_l90.jsonl ../../bench/flou/corpus_flou_temoin_l60.jsonl ../../bench/flou/corpus_flou_temoin_l90.jsonl || true
montre "collage, prose et cas ciblés" -E . 0 non bench_pkg run_collage_fp.dart || true

# Types que le banc ne connaît pas (ATTENTION de run_redact_bench.dart) : un
# seul avertissement pour tout le rejeu ; l'ancien script le jetait (2>&1 > /dev/null).
if [ -s "$NONMAP" ]; then
  echo "AVERTISSEMENT : types d'entité absents de la table de run_redact_bench.dart, comptés tels quels : $(sort -u "$NONMAP" | paste -sd, -)"
fi
if [ "$ECHECS" -gt 0 ]; then
  echo "ÉCHEC : $ECHECS commande(s) en échec ou section(s) vide(s) ci-dessus"
fi
}

# La sortie est affichée au fur et à mesure et gardée pour la vérification.
# Le code de sortie vient de `verifie_etat.py` : il compte les lignes ÉCHEC et
# les lignes attendues manquantes.
set +e
tableau 2>&1 | tee "$LOG"
code=${PIPESTATUS[0]}
set -e
python3 "$B/verifie_etat.py" "$LOG" || code=1
exit "$code"
