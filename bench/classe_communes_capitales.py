#!/usr/bin/env python3
"""Classe les adresses du balayage des communes en capitales qui restent en
partie en clair (P2-196, mesure ; rien ne change dans `lib/`).

Entree : le corpus et les predictions que rejoue `bench/etat.sh`
(`flou/corpus_cedex_balayage_majuscules.jsonl`, `flou/pred_cedex_balayage_
majuscules.jsonl`), donc **`Ecluse.redact`** (ce que recoit le LLM). Les noms
de communes viennent du referentiel public deja versionne
(`geo_communes.csv.gz`), jamais d'un document reel.

Chaque adresse en defaut recoit **une** classe, dans cet ordre, d'apres la
forme du nom de commune ecrit dans le document :

1. `parenthese` : le nom contient une parenthese ;
2. `tiret ou blancs entre deux noms` : le nom contient un tiret isole (« A -
   B ») ou plusieurs espaces de suite (tiret retire par l'ecriture) ;
3. `mot neutre en tete` : le premier mot du nom (apres une eventuelle
   apostrophe) est un mot de `mots_neutres.dart` (« SON », « VERS », « AUX »,
   « D' ») ;
4. `determinant puis mot neutre` : « LES PLACES » ;
5. `numero de CEDEX seul` : le nom est entierement masque, seul le numero de
   CEDEX reste (autre detection de type nom sur la commune) ;
6. `autre`.

N'imprime que des comptes et des exemples du referentiel.

**Axe `sans CEDEX` (P2-206, `--sans`)** : les 338 adresses du balayage en
capitales sans « CEDEX » sont ventilees en cinq **formes** de commune
(`agent/specs/P2-205.md`), une seule par adresse, dans cet ordre :

- `E` mot-cle d'etablissement : une detection de type `etablissement` de
  `Ecluse.redact` recouvre l'adresse annotee (autre detecteur, lu sur les
  predictions, pas sur le nom) ;
- `C` parenthese, tiret isole ou blancs multiples dans le nom ;
- `D` determinant puis mot neutre (« LES PLACES ») ;
- `B` mot neutre en tete, hors LE, LA, LES, L' (« SON », « VERS », « AUX ») ;
- `A` plus de quatre mots (au moins cinq) ;
- `autre` : rien de ce qui precede (doit rester a 0 ; sinon la ventilation
  est incomplete et le dit).

Le scoreur `score_cedex.py` classe par **cause** (longueur, autre,
ponctuation, determinant initial) ; les formes se recoupent avec ces causes
sans s'y superposer : une commune a parenthese de cinq mots est « longueur »
au scoreur et « C » ici.

Usage (depuis la racine, apres `bash bench/etat.sh`) :
    python3 bench/classe_communes_capitales.py          # avec CEDEX (P2-196)
    python3 bench/classe_communes_capitales.py --sans   # sans CEDEX (P2-206)
"""

import collections
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)

from score_cedex import juge, lit  # noqa: E402


def mots_neutres():
    """Lit la liste de `mots_neutres.dart` (source unique, pas de copie)."""
    chemin = os.path.join(ICI, "..", "packages", "ecluse_redact", "lib", "src",
                          "heuristics", "mots_neutres.dart")
    with open(chemin, encoding="utf-8") as f:
        corps = f.read().split("const Set<String> motsNeutres = {", 1)[1]
    corps = corps.split("};", 1)[0]
    return set(re.findall(r"'([^']+)'", re.sub(r"//[^\n]*", "", corps)))


DETERMINANTS = {"le", "la", "les", "l"}


def classe(nom, neutres):
    if "(" in nom or ")" in nom:
        return "parenthèse"
    if re.search(r"\s-\s|\s{2,}", nom):
        return "tiret ou blancs entre deux noms"
    premier = re.split(r"['’\s-]+", nom.strip())
    mots = [m.lower() for m in premier if m]
    if mots and mots[0] in DETERMINANTS and len(mots) > 1 and mots[1] in neutres:
        return "déterminant puis mot neutre"
    if mots and mots[0] in neutres:
        return "mot neutre en tête"
    return "autre"


def forme_sans_cedex(nom, mots, etablissement, neutres):
    """Forme A a E de la commune d'une adresse en defaut (voir l'en-tete).

    `mots` est le nombre de mots du corpus, `etablissement` vrai si une
    detection d'etablissement recouvre l'adresse."""
    if etablissement:
        return "E"
    f = classe(nom, neutres)
    if f in ("parenthèse", "tiret ou blancs entre deux noms"):
        return "C"
    if f == "déterminant puis mot neutre":
        return "D"
    premier = [m.lower() for m in re.split(r"['’\s-]+", nom.strip()) if m]
    if f == "mot neutre en tête" and premier[0] not in DETERMINANTS:
        return "B"
    if mots >= 5:
        return "A"
    return "autre"


FORMES = (
    ("A", "plus de quatre mots"),
    ("B", "mot neutre en tête"),
    ("C", "parenthèse, tiret isolé ou blancs multiples"),
    ("D", "déterminant puis mot neutre"),
    ("E", "mot-clé d'établissement dans le nom"),
    ("autre", "aucune des cinq formes"),
)


def main_sans():
    corpus = lit(os.path.join(ICI, "flou",
                              "corpus_cedex_balayage_sans_majuscules.jsonl"))
    preds = {d["id"]: d for d in lit(os.path.join(
        ICI, "flou", "pred_cedex_balayage_sans_majuscules.jsonl"))}
    neutres = mots_neutres()
    par_forme = collections.defaultdict(list)
    for doc in corpus:
        pred = preds[doc["id"]]
        _, clair, _ = juge(doc, pred)
        if not clair:
            continue
        e = doc["entities"][0]
        etab = any(p["type"] == "etablissement" and p["start"] < e["end"]
                   and p["end"] > e["start"] for p in pred["entities"])
        a, b = doc["parties"]["commune"]
        nom = doc["text"][a:b]
        par_forme[forme_sans_cedex(nom, doc["mots"], etab, neutres)].append(
            (doc, nom))
    total = sum(len(v) for v in par_forme.values())
    print(f"sans CEDEX : {total} adresses en partie en clair sur "
          f"{len(corpus)}, par forme de commune (Ecluse.redact)")
    for lettre, libelle in FORMES:
        v = par_forme.get(lettre, [])
        if not v and lettre == "autre":
            print(f"  forme autre : 0 adresse(s), 0 commune(s) ({libelle})")
            continue
        communes = {d["com"] for d, _ in v}
        vus = []
        for _, nom in v:
            if nom not in vus:
                vus.append(nom)
        print(f"  forme {lettre} : {len(v)} adresse(s), {len(communes)} "
              f"commune(s) ({libelle}) ; exemples : " + " ; ".join(vus[:3]))


def main():
    if "--sans" in sys.argv[1:]:
        main_sans()
        return
    corpus = lit(os.path.join(ICI, "flou",
                              "corpus_cedex_balayage_majuscules.jsonl"))
    preds = {d["id"]: d for d in lit(os.path.join(
        ICI, "flou", "pred_cedex_balayage_majuscules.jsonl"))}
    neutres = mots_neutres()
    par_classe = collections.defaultdict(list)
    for doc in corpus:
        utiles, clair, parties = juge(doc, preds[doc["id"]])
        if not clair:
            continue
        a, b = doc["parties"]["commune"]
        nom = doc["text"][a:b]
        couverts = {i for p in preds[doc["id"]]["entities"]
                    for i in range(p["start"], p["end"])}
        commune_en_clair = any(i not in couverts for i in range(a, b)
                               if not doc["text"][i].isspace())
        c = classe(nom, neutres) if commune_en_clair else "numéro de CEDEX seul"
        par_classe[c].append((doc, nom))
    total = sum(len(v) for v in par_classe.values())
    print(f"adresses en partie en clair : {total} sur {len(corpus)}")
    for c in sorted(par_classe, key=lambda k: (-len(par_classe[k]), k)):
        v = par_classe[c]
        communes = {d["com"] for d, _ in v}
        print(f"classe={c} : {len(v)} adresse(s), {len(communes)} commune(s)")
        vus = []
        for _, nom in v:
            if nom not in vus:
                vus.append(nom)
        print("  exemples : " + " ; ".join(vus[:3]))
        ecr = collections.Counter(d["ecriture"] for d, _ in v)
        print("  écritures : " + ", ".join(f"{k} {n}" for k, n in sorted(ecr.items())))


if __name__ == "__main__":
    main()
