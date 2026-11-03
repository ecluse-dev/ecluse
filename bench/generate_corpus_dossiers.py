#!/usr/bin/env python3
"""Generateur de corpus multi-documents (dossiers).  (P2-05a)

Un DOSSIER est une suite ordonnee de documents qui parlent des memes
personnes. Le corpus sert a mesurer ce que fait `Ecluse.redact` quand on
l'appelle document par document : un meme jeton designe-t-il la meme
personne d'un document a l'autre ? Deux personnes recoivent-elles le meme
jeton ? Voir `agent/specs/P2-05.md`.

Trois corpus distincts, jamais fusionnes :
  - realiste    : 3 a 6 documents par dossier, peu de personnes, mention
                  complete d'abord puis mentions partielles
  - adversarial : pieges denses (ordres differents, homonymes de meme sexe,
                  couple, patronymes courants, mention partielle ambigue,
                  e-mail et telephone repetes, jeton litteral dans le texte,
                  memes personnes dans plusieurs dossiers)
  - temoin      : plusieurs dossiers sans aucune personne commune (aucun
                  nom, e-mail ni telephone partage), pour distinguer une
                  ressemblance de jetons due a la numerotation d'un vrai
                  recoupement

Format (une ligne JSON par document) :
  {"id": int, "dossier": int, "rang": int, "text": str,
   "entities": [{"type": "nom"|"email"|"telephone", "start": int,
                 "end": int, "identite": str|null,
                 "ambigue": bool (seulement si vrai)}]}

`identite` est unique par personne (noms : "p<n>") ou par valeur (e-mail,
telephone : "email:<valeur>", "tel:<valeur>"), et partagee entre dossiers
quand une meme personne ou valeur y figure. Une mention marquee `ambigue`
(patronyme seul porte par deux personnes du dossier) n'a pas d'identite :
aucune lecture n'est correcte, le scoreur la compte a part.

Toutes les valeurs sont synthetiques. Prenoms et noms viennent de
`generate_corpus_flou.py` (plus quelques patronymes inventes pour que le
temoin dispose d'assez de noms distincts). Telephones : plages reservees a
la fiction. E-mails : example.fr / example.com. Aucune lecture externe.

Usage :
    python generate_corpus_dossiers.py --n 400 --seed 42 --out-dir .
"""

import argparse
import json
import random

from generate_corpus_flou import (CIVILITES_F, CIVILITES_M, NOMS,
                                  NOMS_AMBIGUS, PRENOMS_F, PRENOMS_M, Doc,
                                  email, tel)

# Patronymes inventes, en plus de ceux du corpus flou : le temoin exige des
# personnes toutes distinctes, ce que douze patronymes ne permettent pas.
NOMS_PLUS = ["Bourdillon", "Carpentier", "Dufaure", "Esnault", "Fargeot",
             "Gaillard", "Hautecoeur", "Imbert", "Jaquet", "Kerlo",
             "Lacombe", "Maillard", "Nouvel", "Orsini", "Pelletan",
             "Quentel", "Rambaud", "Sabatier", "Tessier", "Urbain"]
TOUS_NOMS = NOMS + NOMS_PLUS

PRENOMS_F_UNIQ = sorted(set(PRENOMS_F))
PRENOMS_M_UNIQ = sorted(set(PRENOMS_M))


class Pers:
    """Une personne synthetique, avec une identite stable dans le corpus."""

    def __init__(self, pid, genre, prenom, nom, rng, tels_pris):
        self.pid = f"p{pid}"
        self.genre = genre
        self.prenom = prenom
        self.nom = nom
        self.civ = rng.choice(CIVILITES_F if genre == "f" else CIVILITES_M)
        self.mail = email(rng, prenom, nom, rng.choice(["simple", "initiale"]))
        # Telephone unique dans le corpus : deux personnes ne partagent
        # jamais un numero, sauf si le scenario le veut.
        for _ in range(100):
            self.tel = tel(rng, rng.choice(["espace", "point"]))
            if self.tel not in tels_pris:
                break
        tels_pris.add(self.tel)

    def texte(self, style):
        return {
            "complet": f"{self.civ} {self.prenom} {self.nom}",
            "civ_nom": f"{self.civ} {self.nom}",
            "prenom_nom": f"{self.prenom} {self.nom}",
            "nom": self.nom,
        }[style]


class Fabrique:
    """Numerotation et unicite des personnes d'un corpus."""

    def __init__(self, rng):
        self.rng = rng
        self.n = 0
        self.tels = set()
        self.noms_pris = set()

    def pers(self, genre=None, nom=None, prenom=None, unique=False):
        rng = self.rng
        genre = genre or rng.choice(["f", "m"])
        liste = PRENOMS_F_UNIQ if genre == "f" else PRENOMS_M_UNIQ
        for _ in range(1000):
            p = prenom or rng.choice(liste)
            n = nom or rng.choice(TOUS_NOMS)
            if not unique or (p, n) not in self.noms_pris:
                break
        else:
            raise SystemExit("temoin : plus assez de noms distincts, "
                             "reduire --n")
        self.noms_pris.add((p, n))
        self.n += 1
        return Pers(self.n, genre, p, n, rng, self.tels)

    def noms_distincts(self, k):
        """k patronymes tous differents (pour que les mentions partielles
        d'un dossier realiste soient univoques)."""
        return self.rng.sample(TOUS_NOMS, k)


# ---------------------------------------------------------------------------
# Phrases : chaque fonction ajoute une mention au document avec son identite.
# ---------------------------------------------------------------------------


def _ent(d, texte, etype, identite, ambigue=False):
    d.ent(texte, etype)
    d.entities[-1]["identite"] = identite
    if ambigue:
        d.entities[-1]["ambigue"] = True


def phrase_nom(d, rng, p, style, ambigue=False):
    identite = None if ambigue else p.pid
    gabarit = rng.randint(0, 4)
    if gabarit == 0:
        d.add("Suite à l'entretien avec ")
        _ent(d, p.texte(style), "nom", identite, ambigue)
        d.add(", le suivi est maintenu.\n")
    elif gabarit == 1:
        d.add("Note de service : le dossier de ")
        _ent(d, p.texte(style), "nom", identite, ambigue)
        d.add(" est transmis à l'équipe de coordination.\n")
    elif gabarit == 2:
        d.add("Rendez-vous reporté à la demande de ")
        _ent(d, p.texte(style), "nom", identite, ambigue)
        d.add(" ; une nouvelle date sera proposée.\n")
    elif gabarit == 3:
        d.add("Compte rendu : ")
        _ent(d, p.texte(style), "nom", identite, ambigue)
        d.add(" a confirmé la réception des pièces demandées.\n")
    else:
        d.add("Pièces jointes au dossier de ")
        _ent(d, p.texte(style), "nom", identite, ambigue)
        d.add(" : attestation et courrier de liaison.\n")


def phrase_contact(d, rng, p, mail=True, tel_=True):
    d.add("Contact : ")
    if mail:
        _ent(d, p.mail, "email", f"email:{p.mail}")
    if mail and tel_:
        d.add(" / ")
    if tel_:
        _ent(d, p.tel, "telephone", f"tel:{p.tel}")
    d.add("\n")


def phrase_neutre(d, rng):
    d.add(rng.choice([
        "Le point d'étape est reporté à la prochaine séance.\n",
        "Aucun changement n'est à signaler depuis le dernier échange.\n",
        "La réunion de synthèse aura lieu en fin de mois.\n",
        "Les documents ont été classés par ordre chronologique.\n",
    ]))


def entete(d, rang):
    d.add(f"Dossier de suivi — pièce {rang + 1}\n\n")


def finalise(docs_par_dossier):
    """Numerote les documents de bout en bout et ajoute dossier/rang."""
    out, doc_id = [], 0
    for dossier, docs in enumerate(docs_par_dossier):
        for rang, d in enumerate(docs):
            doc = d.build(doc_id)
            doc["dossier"] = dossier
            doc["rang"] = rang
            out.append(doc)
            doc_id += 1
    return out


# ---------------------------------------------------------------------------
# CORPUS REALISTE
# ---------------------------------------------------------------------------


def dossier_realiste(rng, fab):
    k = rng.randint(3, 6)
    nb = rng.randint(1, 3)
    noms = fab.noms_distincts(nb)
    personnes = [fab.pers(nom=n) for n in noms]
    docs = []
    for rang in range(k):
        d = Doc()
        entete(d, rang)
        for i, p in enumerate(personnes):
            if rang == 0:
                style = "complet"  # presentation complete d'abord
            else:
                style = rng.choice(["civ_nom", "prenom_nom", "nom",
                                    "complet"])
            if rang == 0 or rng.random() < 0.7:
                phrase_nom(d, rng, p, style)
            if i == 0 and (rang == 0 or rng.random() < 0.4):
                phrase_contact(d, rng, p, mail=rng.random() < 0.8,
                               tel_=rng.random() < 0.8)
        phrase_neutre(d, rng)
        docs.append(d)
    return docs


# ---------------------------------------------------------------------------
# CORPUS ADVERSARIAL
# ---------------------------------------------------------------------------


def piscine(fab):
    """Personnes reutilisees par plusieurs dossiers du corpus adversarial,
    dont deux homonymes de meme sexe et un couple (meme patronyme, sexes
    differents), et des patronymes courants."""
    return {
        "a": fab.pers("f", NOMS_AMBIGUS[0], "Sophie"),
        "b": fab.pers("f", NOMS_AMBIGUS[0], "Laure"),  # homonyme de a
        "c": fab.pers("m", "Verdier", "Thomas"),
        "d": fab.pers("f", "Verdier", "Nathalie"),  # couple avec c
        "e": fab.pers("m", "Petit", "Marc"),
        "f": fab.pers("f", "Berger", "Élodie"),
        "g": fab.pers("m", "Delaunay", "Julien"),
        "h": fab.pers("f", "Delaunay", "Camille"),
    }


def scenario_ordres(rng, pool, k):
    """Deux personnes citees dans des ordres differents d'un document a
    l'autre."""
    a, b = rng.sample(list(pool.values()), 2)
    docs = []
    for rang in range(k):
        d = Doc()
        entete(d, rang)
        for p in ([a, b] if rang % 2 == 0 else [b, a]):
            phrase_nom(d, rng, p, "complet" if rang < 2 else "civ_nom")
        docs.append(d)
    return docs


def scenario_premiere_position(rng, pool, k):
    """Deux personnes distinctes en premiere position, chacune dans son
    propre document."""
    a, b = rng.sample(list(pool.values()), 2)
    docs = []
    for rang in range(k):
        d = Doc()
        entete(d, rang)
        phrase_nom(d, rng, a if rang % 2 == 0 else b, "complet")
        phrase_neutre(d, rng)
        docs.append(d)
    return docs


def scenario_homonymes(rng, pool, k):
    """Homonymes de meme sexe : le patronyme seul est ambigu."""
    a, b = pool["a"], pool["b"]
    docs = []
    for rang in range(k):
        d = Doc()
        entete(d, rang)
        if rang == 0:
            phrase_nom(d, rng, a, "complet")
            phrase_nom(d, rng, b, "complet")
        elif rang % 2 == 1:
            phrase_nom(d, rng, a, "civ_nom", ambigue=True)
        else:
            phrase_nom(d, rng, b, "prenom_nom")
        docs.append(d)
    return docs


def scenario_couple(rng, pool, k):
    """Un couple : meme patronyme, sexes differents. Avec civilite, la
    mention est univoque ; sans civilite elle est ambigue."""
    c, dd = pool["c"], pool["d"]
    docs = []
    for rang in range(k):
        d = Doc()
        entete(d, rang)
        if rang == 0:
            phrase_nom(d, rng, c, "complet")
            phrase_nom(d, rng, dd, "complet")
        elif rang % 2 == 1:
            phrase_nom(d, rng, dd, "civ_nom")
        else:
            phrase_nom(d, rng, c, "nom", ambigue=True)
        docs.append(d)
    return docs


def scenario_courants(rng, pool, k):
    """Patronymes courants (mots de la langue) : precision des fusions."""
    e, f = pool["e"], pool["f"]
    docs = []
    for rang in range(k):
        d = Doc()
        entete(d, rang)
        phrase_nom(d, rng, e if rang % 2 == 0 else f,
                   "complet" if rang < 2 else "civ_nom")
        phrase_nom(d, rng, f if rang % 2 == 0 else e, "nom")
        docs.append(d)
    return docs


def scenario_contacts(rng, pool, k):
    """E-mail et telephone repetes d'un document a l'autre."""
    a, b = rng.sample(list(pool.values()), 2)
    docs = []
    for rang in range(k):
        d = Doc()
        entete(d, rang)
        phrase_nom(d, rng, a, "complet" if rang == 0 else "civ_nom")
        phrase_contact(d, rng, a)
        if rang % 2 == 1:
            phrase_contact(d, rng, b)
        docs.append(d)
    return docs


def scenario_jeton_litteral(rng, pool, k):
    """Un document ulterieur contient le texte litteral « [NOM_1] »."""
    a, b = rng.sample(list(pool.values()), 2)
    docs = []
    for rang in range(k):
        d = Doc()
        entete(d, rang)
        phrase_nom(d, rng, a, "complet" if rang == 0 else "civ_nom")
        if rang >= 1:
            d.add("Extrait d'un brouillon précédent : « [NOM_1] a confirmé "
                  "le rendez-vous ».\n")
        if rang == 2:
            phrase_nom(d, rng, b, "complet")
        docs.append(d)
    return docs


SCENARIOS = [scenario_ordres, scenario_premiere_position,
             scenario_homonymes, scenario_couple, scenario_courants,
             scenario_contacts, scenario_jeton_litteral]


def dossier_adversarial(rng, fab, pool):
    k = rng.randint(3, 6)
    return rng.choice(SCENARIOS)(rng, pool, k)


# ---------------------------------------------------------------------------
# CORPUS TEMOIN
# ---------------------------------------------------------------------------


def dossier_temoin(rng, fab):
    """Personnes toutes nouvelles : aucun nom, e-mail ni telephone
    n'apparait dans un autre dossier."""
    k = rng.randint(3, 6)
    # Patronymes distincts dans le dossier : une mention partielle y est
    # univoque (les homonymes sont l'affaire de l'adversarial).
    noms = fab.noms_distincts(rng.randint(1, 2))
    personnes = [fab.pers(nom=n, unique=True) for n in noms]
    docs = []
    for rang in range(k):
        d = Doc()
        entete(d, rang)
        for p in personnes:
            phrase_nom(d, rng, p, "complet" if rang == 0 else "civ_nom")
        if rang == 0:
            phrase_contact(d, rng, personnes[0])
        docs.append(d)
    return docs


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def construit(nom, n, seed):
    """Liste de documents du corpus `nom` (au plus `n`)."""
    # Un RNG par corpus : ajouter des documents a l'un ne decale pas les
    # autres.
    rng = random.Random(f"{seed}:{nom}")
    fab = Fabrique(rng)
    pool = piscine(fab) if nom == "adversarial" else None
    dossiers, total = [], 0
    while True:
        if nom == "realiste":
            docs = dossier_realiste(rng, fab)
        elif nom == "adversarial":
            docs = dossier_adversarial(rng, fab, pool)
        else:
            docs = dossier_temoin(rng, fab)
        if total + len(docs) > n:
            break
        dossiers.append(docs)
        total += len(docs)
    return finalise(dossiers)


FABRIQUES = [("realiste", None), ("adversarial", None), ("temoin", None)]


def ecrit(path, docs):
    with open(path, "w", encoding="utf-8") as f:
        for doc in docs:
            f.write(json.dumps(doc, ensure_ascii=False) + "\n")


def stats(docs):
    dossiers = {d["dossier"] for d in docs}
    types = {}
    ident = set()
    ambigues = 0
    for d in docs:
        for e in d["entities"]:
            types[e["type"]] = types.get(e["type"], 0) + 1
            if e.get("identite"):
                ident.add(e["identite"])
            ambigues += bool(e.get("ambigue"))
    return len(dossiers), types, len(ident), ambigues


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=400, help="documents par corpus")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out-dir", default=".")
    args = ap.parse_args()

    for nom, _ in FABRIQUES:
        docs = construit(nom, args.n, args.seed)
        path = f"{args.out_dir}/corpus_dossiers_{nom}.jsonl"
        ecrit(path, docs)
        nb_dossiers, types, nb_ident, ambigues = stats(docs)
        print(f"{path} : {len(docs)} documents, {nb_dossiers} dossiers, "
              f"{nb_ident} identités, {ambigues} mention(s) ambiguë(s)")
        for t in sorted(types):
            print(f"    {t:12s} {types[t]:5d} mentions")


if __name__ == "__main__":
    main()
