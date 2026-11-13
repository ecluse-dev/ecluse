#!/usr/bin/env bash
# Équivalence « avec et sans recollage » des détecteurs isolés (P2-171,
# point 2 du plan de agent/specs/P2-162.md § 5). À lancer depuis la racine du
# dépôt, APRÈS `bash bench/etat.sh` (qui génère les corpus, graine 42) :
#     bash bench/collage_equivalence.sh > equivalence.log
#
# Entrées : tous les `.jsonl` de bench/ dont la première ligne porte un champ
# « text » (les corpus ; les fichiers de prédictions n'en ont pas et sont
# écartés ici, leur nombre est imprimé), puis la prose des `.md` suivis par
# git. Chemin mesuré : détecteurs d'`ecluse_core` appelés seuls, sur le texte
# d'origine puis sur le texte recollé par le banc. Ce n'est PAS `Ecluse.redact`
# (ce que reçoit le LLM), et rien n'est changé dans `lib/`.
#
# Le banc n'imprime que des comptes et, pour une différence, l'identifiant du
# document et des positions : jamais une valeur.
set -Eeuo pipefail
R=$(pwd)
[ -f "$R/bench/corpus.jsonl" ] || { echo "ÉCHEC : bench/corpus.jsonl absent (lancer d'abord bench/etat.sh)"; exit 1; }

corpus=()
ecartes=0
while IFS= read -r f; do
  if head -n 1 "$f" | python3 -c 'import json,sys
try:
    d = json.loads(sys.stdin.readline())
except ValueError:
    sys.exit(1)
sys.exit(0 if isinstance(d, dict) and isinstance(d.get("text"), str) else 1)'; then
    corpus+=("$R/$f")
  else
    ecartes=$((ecartes + 1))
  fi
done < <(find bench -name '*.jsonl' | LC_ALL=C sort)

prose=()
while IFS= read -r f; do prose+=("$R/$f"); done < <(git ls-files '*.md' | LC_ALL=C sort)

echo "## équivalence avec et sans recollage : ${#corpus[@]} corpus, ${#prose[@]} fichiers .md ($ecartes .jsonl sans champ text écartés)"
[ "${#corpus[@]}" -gt 0 ] || { echo "ÉCHEC : aucun corpus trouvé (lancer d'abord bench/etat.sh)"; exit 1; }
cd "$R/packages/ecluse_bench"
echo "# corpus"
dart run bin/run_collage_fp.dart --equivalence "${corpus[@]}" < /dev/null | sed "s#$R/##"
echo "# prose"
dart run bin/run_collage_fp.dart --equivalence "${prose[@]}" < /dev/null | sed "s#$R/##"
echo "# voisinage (tirages, graine 42)"
dart run bin/run_collage_fp.dart --equivalence < /dev/null
