#!/usr/bin/env python3
"""Scoreur du corpus « CEDEX apres une commune longue » (P2-178).

D'apres des predictions au format de `run_redact_bench.dart` (donc
**`Ecluse.redact`**, ce que recoit le LLM). Un caractere est « en clair » s'il
n'est sous aucune detection, quel qu'en soit le type ; les blancs ne comptent
pas. Pour chaque valeur d'un axe :

- adresses, et celles qui ont au moins un caractere en clair ;
- fuite au caractere (caracteres en clair / caracteres annotes) ;
- la partie touchee : commune, mot « CEDEX », numero de CEDEX (nombre
  d'adresses ou la partie a au moins un caractere en clair) ;
- la cause, quand le nom de la commune est en partie en clair, lue sur le mot
  ou le masquage s'arrete (voir `cause`).

N'imprime que des comptes ; `--exemples N` ajoute, par nombre de mots, le
texte masque des N premieres adresses en defaut (noms de communes du
referentiel public et reste synthetique : aucune donnee personnelle).

Usage :
    python3 score_cedex.py --corpus c.jsonl --pred p.jsonl [--exemples N]
        [--seulement ecriture=libelle]
"""

import argparse
import collections
import json
import re

AXES = ("mots", "ecriture", "cedex", "voie")


def en_clair(texte, debut, fin, couverts):
    """Positions hors blancs de [debut, fin) sous aucune detection."""
    return [i for i in range(debut, fin)
            if not texte[i].isspace() and i not in couverts]


def juge(doc, pred):
    """Rend (caracteres annotes, caracteres en clair, parties en clair)."""
    texte = doc["text"]
    e = doc["entities"][0]
    couverts = set()
    for p in pred.get("entities", []):
        couverts.update(range(p["start"], p["end"]))
    utiles = sum(1 for i in range(e["start"], e["end"])
                 if not texte[i].isspace())
    clair = en_clair(texte, e["start"], e["end"], couverts)
    parties = {
        nom: bool(bornes and en_clair(texte, bornes[0], bornes[1], couverts))
        for nom, bornes in doc["parties"].items()}
    return utiles, len(clair), parties


# Petits mots que le detecteur d'adresse accepte en minuscules entre deux mots
# d'une commune (`_connecteurs` d'`adresse_detector.dart`). Recopies ici pour
# classer les causes ; le scoreur ne juge pas le detecteur avec.
CONNECTEURS = {"de", "du", "des", "la", "le", "les", "en", "sur", "sous",
               "lès", "lez", "aux"}
# Civilites et titres que le detecteur refuse comme mot de commune (`_titres`).
TITRES = ("Mme", "Mlle", "Mr", "Madame", "Monsieur", "Mademoiselle", "Dr",
          "Docteur", "Pr", "Professeur", "Me", "Maître", "M")
MOT_ASCII = re.compile(r"[A-Za-z0-9_]")


def faux_titre(mot):
    """Vrai si `mot` commence par un titre suivi d'un caractere qui n'est pas
    une lettre ASCII : « Mémont » se lit « M » + frontiere de mot, « Pré »
    se lit « Pr » + frontiere (la frontiere `\\b` ne connait pas les lettres
    accentuees)."""
    mot = re.sub(r"^[dl]['’]", "", mot)
    for titre in TITRES:
        if (mot.startswith(titre) and len(mot) > len(titre)
                and not MOT_ASCII.match(mot[len(titre)])):
            return True
    return False


def cause(doc, couverts):
    """Cause probable d'un nom de commune en partie en clair, ou None.

    Lue sur le premier caractere en clair du nom : le mot ou le masquage
    s'arrete, puis le premier mot qui n'est pas un connecteur admis.

    - `faux titre` : ce mot commence par « M », « Me », « Pr », « Dr »… suivi
      d'une lettre accentuee (« Le Mémont », « Saint-Martin-sur-le-Pré ») ;
    - `liaison absente : <mot>` : mot en minuscules hors de la liste des
      connecteurs (« et », « au », « à », « près ») ;
    - `ponctuation` : parenthese ou tiret isole dans le nom ;
    - `longueur` : au moins quatre mots a majuscule sont deja masques (limite
      du motif : un mot puis trois au plus) ;
    - `milieu de mot`, `autre` : le reste.
    """
    texte = doc["text"]
    debut, fin = doc["parties"]["commune"]
    clair = en_clair(texte, debut, fin, couverts)
    if not clair:
        return None
    mots = [(m.start() + debut, m.group())
            for m in re.finditer(r"\S+", texte[debut:fin])]
    k = max(i for i, (pos, _) in enumerate(mots) if pos <= clair[0])
    if mots[k][0] != clair[0]:
        return "milieu de mot"
    pleins_avant = sum(1 for _, m in mots[:k] if m[0].isupper())
    j = k
    while j < len(mots) and mots[j][1] in CONNECTEURS:
        j += 1
    if j == len(mots):
        return "autre"
    suivant = mots[j][1]
    if faux_titre(suivant):
        return "faux titre"
    if not suivant[0].isalpha():
        return "ponctuation"
    if suivant[0].islower() and not re.match(r"^[dl]['’]", suivant):
        return f"liaison absente : {suivant}"
    if pleins_avant >= 4:
        return "longueur"
    return "autre"


def masque(doc, pred):
    """Texte ou chaque detection est remplacee par [TYPE] (pour un exemple)."""
    texte = doc["text"]
    for p in sorted(pred.get("entities", []), key=lambda p: -p["start"]):
        texte = (texte[:p["start"]] + f"[{p['type'].upper()}]"
                 + texte[p["end"]:])
    return texte.replace("\n", "⏎")


def compte(corpus, preds):
    """Rend ({(axe, valeur): compteurs}, refus, exemples par nombre de mots,
    causes des noms de commune en partie en clair, codes de ces communes)."""
    stats = collections.defaultdict(collections.Counter)
    causes = collections.Counter()
    communes = set()
    exemples = collections.defaultdict(list)
    refus = 0
    for doc in corpus:
        pred = preds.get(doc["id"])
        if pred is None:
            raise SystemExit(f"prediction absente pour le document {doc['id']}")
        if pred.get("refuse"):
            refus += 1
            continue
        utiles, clair, parties = juge(doc, pred)
        couverts = set()
        for q in pred.get("entities", []):
            couverts.update(range(q["start"], q["end"]))
        motif = cause(doc, couverts)
        if motif:
            causes[motif] += 1
            communes.add(doc.get("com"))
        if clair:
            exemples[doc["mots"]].append((doc, pred))
        for axe in AXES + ("mots x ecriture",):
            valeur = (f"{doc['mots']} x {doc['ecriture']}"
                      if axe == "mots x ecriture" else doc[axe])
            c = stats[(axe, valeur)]
            c["adresses"] += 1
            c["utiles"] += utiles
            c["clair"] += clair
            c["en_defaut"] += clair > 0
            for nom, touche in parties.items():
                c[nom] += touche
    return stats, refus, exemples, causes, communes


def lit(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(ligne) for ligne in f if ligne.strip()]


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--corpus", required=True)
    p.add_argument("--pred", required=True)
    p.add_argument("--exemples", type=int, default=0)
    p.add_argument("--seulement", metavar="AXE=VALEUR",
                   help="ne garder que les documents de cette valeur d'axe "
                        "(par exemple ecriture=libelle)")
    a = p.parse_args()
    corpus = lit(a.corpus)
    if a.seulement:
        axe, _, valeur = a.seulement.partition("=")
        corpus = [d for d in corpus if str(d[axe]) == valeur]
    preds = {d["id"]: d for d in lit(a.pred)}
    stats, refus, exemples, causes, communes = compte(corpus, preds)
    total = sum(c["adresses"] for (axe, _), c in stats.items()
                if axe == "mots")
    defaut = sum(c["en_defaut"] for (axe, _), c in stats.items()
                 if axe == "mots")
    print(f"cedex commune longue : {total} adresses, {defaut} avec au moins "
          f"un caractère en clair, {refus} refus (Ecluse.redact)")
    for axe in AXES + ("mots x ecriture",):
        for (a2, valeur), c in sorted(
                ((k, v) for k, v in stats.items() if k[0] == axe),
                key=lambda kv: str(kv[0][1]).rjust(20)):
            part = 100 * c["clair"] / c["utiles"] if c["utiles"] else 0
            print(f"  {axe}={valeur} : {c['en_defaut']} / {c['adresses']} en "
                  f"défaut, fuite au caractère {part:.1f} % "
                  f"({c['clair']} / {c['utiles']}) ; commune {c['commune']}, "
                  f"mot CEDEX {c['cedex']}, numéro {c['numero']}")
    print(f"  communes distinctes au nom en partie en clair, sous au moins "
          f"une écriture : {len(communes)} / "
          f"{len({d.get('com') for d in corpus})}")
    for motif, n in sorted(causes.items(), key=lambda kv: (-kv[1], kv[0])):
        print(f"  cause={motif} : {n} adresse(s) au nom de commune en partie "
              "en clair")
    if a.exemples:
        for mots in sorted(exemples):
            for doc, pred in exemples[mots][:a.exemples]:
                print(f"  exemple mots={mots} ecriture={doc['ecriture']} "
                      f"cedex={doc['cedex']} voie={doc['voie']} : "
                      f"{masque(doc, pred)}")


if __name__ == "__main__":
    main()
