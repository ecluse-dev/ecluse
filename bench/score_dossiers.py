#!/usr/bin/env python3
"""Scoreur des corpus de dossiers.  (P2-05a)

Mesure ce que fait un masquage appele document par document sur un dossier
(suite de documents sur les memes personnes, voir
`generate_corpus_dossiers.py`). Six mesures, jamais une seule :

  1. COHERENCE     — part des identites citees au moins deux fois dans un
                     dossier qui recoivent un SEUL jeton. Une identite a
                     deux jetons est une personne que le LLM ne peut pas
                     suivre d'un document a l'autre.
  2. COLLISIONS    — jetons qui, dans un dossier, designent plusieurs
                     identites (« [NOM_1] » est Mme A au document 1 et
                     M. B au document 2). C'est le defaut dangereux : une
                     restauration avec la mauvaise table remplace une
                     personne par une autre.
  3. FAUSSES FUSIONS — jetons qui, DANS UN MEME DOCUMENT, couvrent plusieurs
                     identites. Sous-ensemble strict des collisions, mais
                     c'est le seul cas ou une restauration avec la bonne
                     table se trompe.
  4. RESTAURATIONS NON IDENTIQUES — documents dont le texte masque puis
                     restaure n'est pas identique a l'original, octet pour
                     octet (champ « restaure » des predictions).
  5. RECOUPEMENT   — pour les identites presentes dans au moins deux
                     dossiers : part des paires de dossiers ou elles
                     recoivent le meme jeton principal. SIGNAL STRUCTUREL,
                     a ne pas interpreter tant que la menace n'est pas
                     confirmee (spec P2-05). Il est donne avec sa
                     reference : la part, parmi les identites DISTINCTES de
                     dossiers distincts, qui recoivent le meme jeton par le
                     seul effet de la numerotation.
  6. AMBIGUES      — mentions marquees `ambigue` (aucune lecture correcte),
                     comptees a part et jamais dans les mesures ci-dessus.

Une mention annotee que la detection n'a pas trouvee n'a pas de jeton : elle
est comptee (« non detectees ») et exclue des mesures 1 a 3, sans quoi un
oubli de detection passerait pour une incoherence ou, pire, pour une
coherence.

Format des predictions (une ligne par document) :
  {"id": int,
   "mentions": [{"type": str, "start": int, "end": int, "jeton": str}],
   "restaure": bool}

Usage :
    python score_dossiers.py --corpus corpus_dossiers_realiste.jsonl \\
        --pred pred_dossiers_realiste.jsonl
"""

import argparse
import json
from collections import Counter, defaultdict
from itertools import combinations


def charge(path):
    docs = {}
    for ligne in open(path, encoding="utf-8"):
        if ligne.strip():
            d = json.loads(ligne)
            docs[d["id"]] = d
    return docs


def _chevauche(a, b):
    return a["start"] < b["end"] and b["start"] < a["end"]


def associe(corpus, preds):
    """Pour chaque mention annotee : le jeton recu, ou None si la mention
    n'a pas ete detectee (meme type, chevauchement ; chaque prediction ne
    sert qu'une fois, la plus recouvrante d'abord)."""
    res = []  # (doc, entite annotee, jeton | None)
    for doc_id, doc in corpus.items():
        mentions = preds.get(doc_id, {}).get("mentions", [])
        pris = set()
        for g in doc["entities"]:
            meilleur, taille = None, 0
            for i, p in enumerate(mentions):
                if i in pris or p["type"] != g["type"]:
                    continue
                if not _chevauche(g, p):
                    continue
                t = min(g["end"], p["end"]) - max(g["start"], p["start"])
                if t > taille:
                    meilleur, taille = i, t
            if meilleur is None:
                res.append((doc, g, None))
            else:
                pris.add(meilleur)
                res.append((doc, g, mentions[meilleur]["jeton"]))
    return res


def _principal(jetons):
    """Jeton le plus frequent (a egalite, le plus petit par ordre
    alphabetique, pour rester deterministe)."""
    c = Counter(jetons)
    return sorted(c, key=lambda j: (-c[j], j))[0]


def _paires(n):
    return n * (n - 1) // 2


def mesure(corpus, preds):
    """Dictionnaire de mesures pour un corpus et ses predictions."""
    liens = associe(corpus, preds)
    non_detectees = Counter()
    ambigues = {"total": 0, "detectees": 0, "fusionnees": 0,
                "fusionnees_dossier": 0}

    # Jetons par (dossier, identite) et par (dossier, document).
    par_ident = defaultdict(list)  # (dossier, identite, type) -> [jeton]
    par_jeton = defaultdict(set)   # (dossier, jeton) -> {identite}
    par_doc = defaultdict(set)     # (doc, jeton) -> {identite}
    jetons_doc_ident = defaultdict(set)  # doc -> jetons d'identites connues
    ambigues_doc = []              # (doc, jeton)
    ambigues_dossier = []          # (dossier, jeton)
    jetons_dossier_ident = defaultdict(set)  # dossier -> jetons d'identites

    for doc, g, jeton in liens:
        if g.get("ambigue"):
            ambigues["total"] += 1
            if jeton is not None:
                ambigues["detectees"] += 1
                ambigues_doc.append((doc["id"], jeton))
                ambigues_dossier.append((doc["dossier"], jeton))
            continue
        if jeton is None:
            non_detectees[g["type"]] += 1
            continue
        ident = g["identite"]
        par_ident[(doc["dossier"], ident, g["type"])].append(jeton)
        par_jeton[(doc["dossier"], jeton)].add(ident)
        par_doc[(doc["id"], jeton)].add(ident)
        jetons_doc_ident[doc["id"]].add(jeton)
        jetons_dossier_ident[doc["dossier"]].add(jeton)
    ambigues["fusionnees"] = sum(1 for d, j in ambigues_doc
                                 if j in jetons_doc_ident[d])
    ambigues["fusionnees_dossier"] = sum(
        1 for d, j in ambigues_dossier if j in jetons_dossier_ident[d])

    # 1. Coherence : identites citees >= 2 fois dans un dossier.
    coherence = defaultdict(lambda: [0, 0])  # type -> [un seul jeton, total]
    for (dossier, ident, t), jetons in par_ident.items():
        if len(jetons) < 2:
            continue
        coherence[t][1] += 1
        coherence["tous"][1] += 1
        if len(set(jetons)) == 1:
            coherence[t][0] += 1
            coherence["tous"][0] += 1

    # 2. Collisions et 3. fausses fusions.
    collisions = sum(1 for ids in par_jeton.values() if len(ids) > 1)
    jetons_total = len(par_jeton)
    fusions = sum(1 for ids in par_doc.values() if len(ids) > 1)
    jetons_doc_total = len(par_doc)

    # 4. Restaurations non identiques.
    nb_docs = len(corpus)
    non_restaures = sum(
        1 for d in corpus if not preds.get(d, {}).get("restaure", False))

    # 5. Recoupement : jeton principal d'une identite dans chaque dossier.
    principal = {}  # (identite, dossier) -> jeton principal
    for (dossier, ident, t), jetons in par_ident.items():
        principal[(ident, dossier)] = _principal(jetons)
    dossiers_de = defaultdict(list)
    for (ident, dossier), j in principal.items():
        dossiers_de[ident].append((dossier, j))
    identites_partagees = 0
    paires = meme = 0
    for ident, lst in dossiers_de.items():
        if len(lst) < 2:
            continue
        identites_partagees += 1
        for (_, ja), (_, jb) in combinations(lst, 2):
            paires += 1
            meme += ja == jb

    # Reference : identites DISTINCTES de dossiers DISTINCTS, meme jeton.
    # Pour chaque jeton, paires - memes dossiers - memes identites (les
    # entrees (identite, dossier) sont uniques : pas de terme croise).
    par_tok = defaultdict(list)
    for (ident, dossier), j in principal.items():
        par_tok[j].append((ident, dossier))
    total_entrees = len(principal)
    ref_meme = 0
    for j, lst in par_tok.items():
        n = len(lst)
        pd = Counter(d for _, d in lst)
        pi = Counter(i for i, _ in lst)
        ref_meme += (_paires(n) - sum(_paires(c) for c in pd.values())
                     - sum(_paires(c) for c in pi.values()))
    d_entrees = Counter(d for _, d in principal)
    i_entrees = Counter(i for i, _ in principal)
    ref_total = (_paires(total_entrees)
                 - sum(_paires(c) for c in d_entrees.values())
                 - sum(_paires(c) for c in i_entrees.values()))

    return {
        "documents": nb_docs,
        "dossiers": len({d["dossier"] for d in corpus.values()}),
        "non_detectees": dict(non_detectees),
        "coherence": {t: tuple(v) for t, v in coherence.items()},
        "collisions": (collisions, jetons_total),
        "fausses_fusions": (fusions, jetons_doc_total),
        "non_restaures": (non_restaures, nb_docs),
        "recoupement": {
            "identites_partagees": identites_partagees,
            "paires": paires,
            "meme_jeton": meme,
            "reference_paires": ref_total,
            "reference_meme_jeton": ref_meme,
        },
        "ambigues": ambigues,
    }


def _pct(a, b):
    return "n/a" if b == 0 else f"{100 * a / b:5.1f} %"


def affiche(nom, m):
    print(f"=== {nom} : {m['documents']} documents, {m['dossiers']} dossiers")
    coh = m["coherence"]
    print("  Cohérence (identités citées ≥ 2 fois dans un dossier, un seul "
          "jeton)")
    for t in ["tous", "nom", "email", "telephone"]:
        if t in coh:
            a, b = coh[t]
            print(f"    {t:10s} {a:5d} / {b:5d}  {_pct(a, b)}")
    if not coh:
        print("    (aucune identité citée deux fois)")
    a, b = m["collisions"]
    print(f"  Collisions (jeton désignant plusieurs identités dans un "
          f"dossier) : {a} / {b} jetons  {_pct(a, b)}")
    a, b = m["fausses_fusions"]
    print(f"  Fausses fusions (jeton couvrant plusieurs identités dans un "
          f"même document) : {a} / {b}  {_pct(a, b)}")
    a, b = m["non_restaures"]
    print(f"  Restaurations non identiques : {a} / {b} documents  "
          f"{_pct(a, b)}")
    r = m["recoupement"]
    print(f"  Recoupement : {r['identites_partagees']} identités dans ≥ 2 "
          f"dossiers, {r['paires']} paires de dossiers")
    print(f"    même jeton pour la même identité : {r['meme_jeton']} / "
          f"{r['paires']}  {_pct(r['meme_jeton'], r['paires'])}")
    print(f"    référence, identités distinctes de dossiers distincts : "
          f"{r['reference_meme_jeton']} / {r['reference_paires']}  "
          f"{_pct(r['reference_meme_jeton'], r['reference_paires'])}")
    am = m["ambigues"]
    print(f"  Mentions ambiguës (à part) : {am['total']} ; détectées "
          f"{am['detectees']} ; portant le jeton d'une identité connue du "
          f"même document {am['fusionnees']}, du même dossier "
          f"{am['fusionnees_dossier']}")
    if m["non_detectees"]:
        nd = ", ".join(f"{t} {n}" for t, n in sorted(
            m["non_detectees"].items()))
        print(f"  Mentions annotées non détectées (exclues) : {nd}")
    else:
        print("  Mentions annotées non détectées (exclues) : aucune")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred", required=True)
    ap.add_argument("--nom", default=None)
    args = ap.parse_args()
    corpus = charge(args.corpus)
    preds = charge(args.pred)
    affiche(args.nom or args.corpus, mesure(corpus, preds))


if __name__ == "__main__":
    main()
