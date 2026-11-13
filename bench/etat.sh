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
mkdir -p "$B"/{flou,qi,dossiers,patho,transcrit}
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
  "$B"/{flou,qi,dossiers,patho,transcrit}/*.jsonl "$B"/flou/*.traites
echo "## commit $(git rev-parse --short HEAD)"

echo "## v3 (identifiants structurels)"
produit "générateur v3" "$B/corpus.jsonl" python3 "$B/generate_corpus.py" --n 1000 --seed 42 --out "$B/corpus.jsonl" || true
if produit "v3, moteur seul" "$B/predictions_ecluse.jsonl" bench_pkg run_ecluse.dart ../../bench/corpus.jsonl ../../bench/predictions_ecluse.jsonl; then
  montre "v3, score" -E "TOTAL|FINESS" 2 non dans_B python3 score.py --corpus corpus.jsonl --pred "Ecluse=predictions_ecluse.jsonl" || true
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

# Identifiant suivi d'une date, d'un âge ou d'un nombre (P2-174) : 4 types x
# 4 familles x 3 séparateurs x 100 documents. Un identifiant non couvert est
# une fuite ; un type faux ou une suite avalée abîme le texte sans fuite.
echo "## identifiant suivi d'un nombre (P2-174) : Ecluse.redact (chemin du produit)"
produit "générateur identifiant suivi" "$B/flou/corpus_identifiant_suivi.jsonl" dans_B python3 generate_corpus_identifiant_suivi.py --n 100 --seed 42 --out flou/corpus_identifiant_suivi.jsonl || true
if produit "identifiant suivi, Ecluse.redact" "$B/flou/pred_identifiant_suivi.jsonl" redact run_redact_bench.dart ../../bench/flou/corpus_identifiant_suivi.jsonl ../../bench/flou/pred_identifiant_suivi.jsonl; then
  montre "identifiant suivi, score" -E "^identifiant suivi|type_id=|separateur=|^  défaut" 0 non dans_B python3 score_identifiant_suivi.py --corpus flou/corpus_identifiant_suivi.jsonl --pred flou/pred_identifiant_suivi.jsonl || true
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
