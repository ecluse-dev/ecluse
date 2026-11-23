#!/usr/bin/env bash
# Équivalence octet pour octet de deux jeux de prédictions (P2-267, étape 1 de la
# fiche : « tous les corpus existants donnent des prédictions identiques avant et
# après »).
#
# Usage, depuis la racine du dépôt :
#     # 1. sur main, rejouer les corpus puis copier les prédictions
#     bash bench/etat.sh > /dev/null 2>&1
#     mkdir -p /tmp/avant && find bench -name 'pred*.jsonl' | xargs -I{} cp --parents {} /tmp/avant/
#     # 2. sur la branche, rejouer, puis comparer
#     bash bench/etat.sh > /dev/null 2>&1
#     bash bench/equivalence_predictions.sh /tmp/avant [fichier_attendu_different ...]
#
# Les fichiers donnés en arguments suivants (motifs de nom) sont ceux que la
# tâche DOIT changer ; tout autre écart fait échouer le script (code 1), tout
# fichier « attendu différent » qui n'a pas changé aussi (une correction qui ne
# change rien n'en est pas une). Aucune valeur de texte n'est imprimée : des noms
# de fichiers et des comptes seulement.
set -euo pipefail
AVANT=${1:?dossier des prédictions avant la tâche}
shift
ATTENDUS=("$@")
identiques=0
attendus_changes=0
echec=0
while IFS= read -r f; do
  ref="$AVANT/$f"
  if [ ! -f "$ref" ]; then
    echo "NOUVEAU (absent d'avant) : $f"
    echec=1
    continue
  fi
  attendu=0
  for m in "${ATTENDUS[@]:-}"; do
    [ -n "$m" ] && [[ "$f" == *$m* ]] && attendu=1
  done
  if cmp -s "$f" "$ref"; then
    if [ "$attendu" -eq 1 ]; then
      echo "ÉCHEC : attendu différent mais identique : $f"
      echec=1
    else
      identiques=$((identiques + 1))
    fi
  else
    if [ "$attendu" -eq 1 ]; then
      attendus_changes=$((attendus_changes + 1))
    else
      echo "ÉCHEC : différent sans que la tâche le prévoie : $f"
      echec=1
    fi
  fi
done < <(find bench -name 'pred*.jsonl' | sort)
echo "identiques : $identiques ; différents comme prévu : $attendus_changes"
exit "$echec"
