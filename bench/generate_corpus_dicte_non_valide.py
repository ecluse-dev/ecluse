#!/usr/bin/env python3
"""Corpus « identifiants dictés non validés » (P2-274, mesure).

Part des variantes dictées de P2-160/P2-267 (`corpus_transcrit_*.jsonl`, hors
`sans_ponctuation` où les chiffres ne sont pas dictés en lettres) et abîme, dans
chaque document, le **premier** NIR ou IBAN annoté (un seul par document, pour
que le signalement du document lui soit attribuable) :

  mot_perdu  : un mot-nombre de l'identifiant est supprimé (la transcription
               vocale a avalé un mot) ;
  cle_fausse : le dernier mot-nombre est remplacé par un autre chiffre dit
               (la clé de contrôle n'est plus juste).

L'entité annotée garde le type et reçoit les bornes de l'identifiant abîmé ;
les autres entités du document sont retirées de l'annotation. Aucune valeur
n'est imprimée. Synthétique, graine fixe.

Usage :
    python3 generate_corpus_dicte_non_valide.py --in-dir transcrit --out-dir transcrit --seed 42
"""
import argparse
import json
import random

VARIANTES = ["en_lettres", "double_triple", "regional", "zero_o", "sans_traits_union"]
UNITES = ["zéro", "un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf"]
MOTS = set(UNITES) | {
    "dix", "onze", "douze", "treize", "quatorze", "quinze", "seize", "vingt",
    "trente", "quarante", "cinquante", "soixante", "septante", "huitante",
    "nonante", "cent", "mille", "et", "double", "triple", "o", "zero", "quatre-vingt",
}


def est_mot_nombre(jeton):
    return all(p in MOTS for p in jeton.split("-"))


def abime(texte, e, mode, rng):
    debut, fin = e["start"], e["end"]
    jetons = texte[debut:fin].split(" ")
    idx = [i for i, j in enumerate(jetons) if est_mot_nombre(j) and j != "et"]
    if len(idx) < 3:
        return None
    if mode == "mot_perdu":
        del jetons[rng.choice(idx)]
    else:
        i = idx[-1]
        autres = [u for u in UNITES if u != jetons[i]]
        jetons[i] = rng.choice(autres)
    nouveau = " ".join(jetons)
    return texte[:debut] + nouveau + texte[fin:], debut, debut + len(nouveau)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in-dir", required=True)
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--seed", type=int, default=42)
    a = ap.parse_args()
    for mode in ("mot_perdu", "cle_fausse"):
        sortie = []
        for variante in VARIANTES:
            rng = random.Random(f"{a.seed}-{mode}-{variante}")
            for l in open(f"{a.in_dir}/corpus_transcrit_{variante}.jsonl", encoding="utf-8"):
                d = json.loads(l)
                cand = [e for e in d["entities"] if e["type"] in ("nir", "iban")]
                if not cand:
                    continue
                e = min(cand, key=lambda x: x["start"])
                r = abime(d["text"], e, mode, rng)
                if r is None:
                    continue
                texte, s, f = r
                sortie.append({"id": len(sortie), "text": texte,
                               "entities": [{"type": e["type"], "start": s, "end": f}],
                               "variante": variante, "mode": mode})
        chemin = f"{a.out_dir}/corpus_dicte_non_valide_{mode}.jsonl"
        with open(chemin, "w", encoding="utf-8") as f:
            for d in sortie:
                f.write(json.dumps(d, ensure_ascii=False) + "\n")
        print(f"{chemin} : {len(sortie)} documents")


main()
