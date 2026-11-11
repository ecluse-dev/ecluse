#!/usr/bin/env bash
# Rejoue tous les corpus du dépôt sur l'état courant (P2-130) et imprime
# les lignes de synthèse. Graine 42 partout. Depuis la racine du dépôt :
#     bash bench/etat.sh > etat.log 2>&1
# Les fichiers générés vont dans bench/{flou,qi,dossiers,patho,transcrit}/,
# non versionnés. Presidio n'est pas rejoué ici (environnement à part,
# voir README « Reproduire »).
set -euo pipefail
R=$(pwd)
B=$R/bench
mkdir -p "$B"/{flou,qi,dossiers,patho,transcrit}
redact() { (cd "$R/packages/ecluse_redact" && dart run "bin/$1" "${@:2}" < /dev/null); }
reid() { (cd "$R/packages/ecluse_reid" && dart run "bin/$1" "${@:2}" < /dev/null); }

echo "## commit $(git rev-parse --short HEAD)"

echo "## v3 (identifiants structurels)"
python3 "$B/generate_corpus.py" --n 1000 --seed 42 --out "$B/corpus.jsonl" > /dev/null
(cd "$R/packages/ecluse_bench" && dart run bin/run_ecluse.dart ../../bench/corpus.jsonl ../../bench/predictions_ecluse.jsonl < /dev/null > /dev/null)
(cd "$B" && python3 score.py --corpus corpus.jsonl --pred "Ecluse=predictions_ecluse.jsonl" | grep -E "TOTAL|FINESS" | head -2)

echo "## v3 transcrit"
python3 "$B/generate_corpus_transcrit.py" --corpus "$B/corpus.jsonl" --seed 42 --out-dir "$B/transcrit" > /dev/null
for v in sans_ponctuation en_lettres; do
  (cd "$R/packages/ecluse_bench" && dart run bin/run_ecluse.dart "../../bench/transcrit/corpus_transcrit_$v.jsonl" "../../bench/transcrit/pred_$v.jsonl" < /dev/null > /dev/null)
  echo "# $v"; (cd "$B" && python3 score.py --corpus "transcrit/corpus_transcrit_$v.jsonl" --pred "Ecluse=transcrit/pred_$v.jsonl" | grep -E "TOTAL" | head -1)
done

echo "## flou (entités floues) et variantes de casse"
python3 "$B/generate_corpus_flou.py" --n 400 --seed 42 --out-dir "$B/flou" > /dev/null
python3 "$B/variantes_casse.py" "$B"/flou/corpus_flou_{realiste,adversarial,temoin}.jsonl > /dev/null
python3 "$R/bench/generate_corpus_faux_amis_prenoms.py" --n 400 --seed 42 --out "$B/flou/corpus_flou_fauxamis.jsonl" > /dev/null
for c in realiste adversarial temoin realiste_minuscules adversarial_minuscules temoin_minuscules realiste_majuscules adversarial_majuscules temoin_majuscules realiste_phrase adversarial_phrase temoin_phrase fauxamis; do
  n=$(redact run_redact_bench.dart "../../bench/flou/corpus_flou_$c.jsonl" "../../bench/flou/etat_$c.jsonl" 2>&1 > /dev/null | grep -c ALERTE || true)
  echo "# $c"
  echo "  restaurations non identiques (harmonisation, LIMITES 5.3) : $n"
  (cd "$B" && python3 score_flou.py --corpus "flou/corpus_flou_$c.jsonl" --pred "Ecluse=flou/etat_$c.jsonl" | grep -E "^GLOBAL|^nom |^adresse |^etablissement " || true)
  python3 -c "import json,sys;print('  entites predites',sum(len(json.loads(l)['entities']) for l in open(sys.argv[1])))" "$B/flou/etat_$c.jsonl"
done

echo "## quasi-identifiants (ecluse_reid)"
python3 "$B/generate_corpus_qi.py" --n 400 --seed 42 --out-dir "$B/qi" > /dev/null
for c in realiste adversarial temoin; do
  reid run_reid_bench.dart "../../bench/qi/corpus_qi_$c.jsonl" "../../bench/qi/pred_qi_$c.jsonl" > /dev/null
  echo "# $c"; python3 "$B/score_qi.py" --corpus "$B/qi/corpus_qi_$c.jsonl" --pred "Ecluse=$B/qi/pred_qi_$c.jsonl" | grep -E "^(age|lieu|profession|GLOBAL|TOTAL)|extractions" | head -6 || true
done

echo "## généralisation appliquée"
for c in realiste adversarial temoin; do
  echo "# $c"; redact run_generalisation_bench.dart "../../bench/qi/corpus_qi_$c.jsonl" | grep -iE "suggestion|refus|médian|bande|plafond" | head -6 || true
done
echo "# lieu"; redact run_generalisation_lieu_bench.dart | grep -iE "relu|F recalcul|bande recalcul" || true

echo "## dossiers (avec Dossier)"
python3 "$B/generate_corpus_dossiers.py" --n 400 --seed 42 --out-dir "$B/dossiers" > /dev/null
for c in realiste adversarial temoin; do python3 "$B/variantes_casse.py" "$B/dossiers/corpus_dossiers_$c.jsonl" > /dev/null; done
for c in realiste adversarial temoin realiste_minuscules realiste_majuscules realiste_mixte adversarial_minuscules adversarial_mixte temoin_mixte; do
  redact run_dossiers_bench.dart --dossier "../../bench/dossiers/corpus_dossiers_$c.jsonl" "../../bench/dossiers/pred_$c.jsonl" > /dev/null
  echo "# $c"; python3 "$B/score_dossiers.py" --corpus "$B/dossiers/corpus_dossiers_$c.jsonl" --pred "$B/dossiers/pred_$c.jsonl" | grep -iE "coh|collision|fusion|restaur|non d" | head -6 || true
done

echo "## pathologies"
python3 "$B/generate_corpus_pathologies.py" --n 300 --seed 42 --out-dir "$B/patho" > /dev/null
for c in indices variantes; do
  echo "# $c"; reid run_pathologies_bench.dart "../../bench/patho/corpus_pathologies_$c.jsonl" "../../bench/patho/corpus_pathologies_temoin.jsonl" | sed -n '/rattachées/,$p' | grep -E "indices :|témoin :" || true
done
echo "# formes_libres"; reid run_formes_libres.dart ../../bench/patho/corpus_pathologies_formes_libres.jsonl | grep TOTAL || true
echo "# maladies rares masquées (P2-143)"; redact run_maladies_rares_bench.dart ../../bench/patho | grep -E "indices :|temoin :|échantillon" || true

echo "## mise en page (P2-153) : textes recoupés aux espaces, largeur 60 puis 90"
# Un refus explicite (tableau ambigu) n'envoie rien : il est compté à part et
# retiré du corpus noté ; la fuite se lit sur les documents traités.
for w in 60 90; do
  for c in realiste adversarial temoin; do
    python3 "$B/generate_corpus_mise_en_page.py" "$B/flou/corpus_flou_$c.jsonl" --largeur $w --out "$B/flou/corpus_flou_${c}_l$w.jsonl" > /dev/null
    refus=$(redact run_redact_bench.dart "../../bench/flou/corpus_flou_${c}_l$w.jsonl" "../../bench/flou/etat_${c}_l$w.jsonl" 2>&1 > /dev/null | grep -c REFUS || true)
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
    (cd "$B" && python3 score_flou.py --corpus "flou/corpus_flou_${c}_l$w.jsonl.traites" --pred "Ecluse=flou/etat_${c}_l$w.jsonl" | grep -E "^GLOBAL|^nom |^adresse |^etablissement " || true)
  done
  python3 "$B/generate_corpus_mise_en_page.py" "$B/corpus.jsonl" --largeur $w --out "$B/flou/structurel_l$w.jsonl" > /dev/null
  (cd "$R/packages/ecluse_bench" && dart run bin/run_ecluse.dart "../../bench/flou/structurel_l$w.jsonl" "../../bench/flou/pred_structurel_l$w.jsonl" < /dev/null > /dev/null)
  echo "# structurel largeur $w"; (cd "$B" && python3 score.py --corpus "flou/structurel_l$w.jsonl" --pred "Ecluse=flou/pred_structurel_l$w.jsonl" | grep -E "^Ecluse +(nir|rpps|iban|finess|TOTAL)" | head -5 || true)
done
