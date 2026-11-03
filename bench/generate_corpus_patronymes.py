#!/usr/bin/env python3
"""Generateur de corpus pour le patronyme seul.  (P2-14)

`LIMITES.md` (§ 5.2 et § 5.4) pose qu'un patronyme sans civilite ni prenom
n'est masque que s'il a ete etabli plus haut dans le MEME document. Ce
profil separe les cas pour mesurer ce qui est reellement couvert :

  - a        : patronyme seul apres une mention complete du meme document
  - b        : patronyme seul en premiere mention (aucun ancrage)
  - c        : patronyme seul dans un document ulterieur du dossier, la
               mention complete etant dans le premier document
  - leurres  : documents ulterieurs d'un dossier dont le patronyme coincide
               avec un mot courant, mais ou ce mot n'est PAS une personne
               (« Petit dejeuner », « Marchand de journaux »). Aucune
               entite annotee : toute detection est un faux positif.

Format (une ligne JSON par document, comme `generate_corpus_dossiers.py`) :
  {"id", "dossier", "rang", "text",
   "entities": [{"type": "nom", "start", "end", "identite", "cas"}]}
`cas` vaut « ancre » (mention complete, hors mesure), « a », « b_debut »,
« b_milieu », « c_debut » ou « c_milieu ». Valeurs synthetiques, aucune
lecture externe.

Usage :
    python generate_corpus_patronymes.py --n 400 --seed 42 --out-dir .
"""

import argparse
import json
import random

from generate_corpus_dossiers import Fabrique, TOUS_NOMS, finalise
from generate_corpus_flou import Doc

DEBUTS = ["{} a confirmé le rendez-vous.\n", "{} rappelle demain matin.\n",
          "{} n'a pas répondu au courrier.\n"]
MILIEUX = ["Le dossier de {} est transmis à l'équipe de coordination.\n",
           "Rendez-vous reporté à la demande de {} ; une date sera proposée.\n",
           "Courrier adressé à {}.\n"]

# Patronymes qui sont aussi des mots courants, avec une phrase de leurre qui
# emploie ce mot sans designer personne. « Rose » est volontairement absent :
# c'est aussi un prenom du gazetteer, donc deja detecte seul (faux positif
# preexistant, sans rapport avec le patronyme etabli).
LEURRES = {
    "Petit": ["Petit déjeuner servi à 8 h.\n",
              "Lecture du Petit Prince en groupe.\n"],
    "Berger": ["Berger allemand signalé au portail.\n"],
    "Boulanger": ["Boulanger du quartier ouvert le dimanche.\n"],
    "Marchand": ["Marchand de journaux au coin de la rue.\n"],
}


def entete(d, rang):
    d.add(f"Dossier de suivi — pièce {rang + 1}\n\n")


def ent(d, texte, identite, cas):
    d.ent(texte, "nom")
    d.entities[-1]["identite"] = identite
    d.entities[-1]["cas"] = cas


def mention_seule(d, rng, nom, identite, prefixe):
    """Ajoute une phrase avec le patronyme seul ; retourne ('debut'|'milieu')."""
    if rng.random() < 0.5:
        gabarit, cas = rng.choice(DEBUTS), prefixe + "_debut"
    else:
        gabarit, cas = rng.choice(MILIEUX), prefixe + "_milieu"
    avant, apres = gabarit.split("{}")
    d.add(avant)
    ent(d, nom, identite, cas)
    d.add(apres)


def ancre(d, rng, p):
    d.add(rng.choice(["Compte rendu : ", "Entretien avec "]))
    ent(d, p.texte("complet"), p.pid, "ancre")
    d.add(" ce matin.\n")


def corpus_a(rng, fab):
    p = fab.pers(nom=rng.choice(TOUS_NOMS))
    d = Doc()
    entete(d, 0)
    ancre(d, rng, p)
    d.add("Suite de l'échange. ")
    ent(d, p.nom, p.pid, "a")
    d.add(" a confirmé le rendez-vous.\n")
    return [d]


def corpus_b(rng, fab):
    p = fab.pers(nom=rng.choice(TOUS_NOMS))
    d = Doc()
    entete(d, 0)
    mention_seule(d, rng, p.nom, p.pid, "b")
    return [d]


def corpus_c(rng, fab):
    p = fab.pers(nom=rng.choice(TOUS_NOMS))
    docs = []
    for rang in range(rng.randint(2, 3)):
        d = Doc()
        entete(d, rang)
        if rang == 0:
            ancre(d, rng, p)
        else:
            mention_seule(d, rng, p.nom, p.pid, "c")
        docs.append(d)
    return docs


def corpus_leurres(rng, fab):
    nom = rng.choice(sorted(LEURRES))
    p = fab.pers(nom=nom)
    docs = []
    for rang in range(rng.randint(2, 4)):
        d = Doc()
        entete(d, rang)
        if rang == 0:
            ancre(d, rng, p)
        else:
            d.add(rng.choice(LEURRES[nom]))
        docs.append(d)
    return docs


FABRIQUES = [("a", corpus_a), ("b", corpus_b), ("c", corpus_c),
             ("leurres", corpus_leurres)]


def construit(nom, n, seed):
    rng = random.Random(f"{seed}:patronymes:{nom}")
    fab = Fabrique(rng)
    factory = dict(FABRIQUES)[nom]
    dossiers, total = [], 0
    while True:
        docs = factory(rng, fab)
        if total + len(docs) > n:
            break
        dossiers.append(docs)
        total += len(docs)
    return finalise(dossiers)


def ecrit(path, docs):
    with open(path, "w", encoding="utf-8") as f:
        for doc in docs:
            f.write(json.dumps(doc, ensure_ascii=False) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=400, help="documents par corpus")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out-dir", default=".")
    args = ap.parse_args()
    for nom, _ in FABRIQUES:
        docs = construit(nom, args.n, args.seed)
        path = f"{args.out_dir}/corpus_patronymes_{nom}.jsonl"
        ecrit(path, docs)
        cas = {}
        for d in docs:
            for e in d["entities"]:
                cas[e["cas"]] = cas.get(e["cas"], 0) + 1
        print(f"{path} : {len(docs)} documents, mentions par cas {cas}")


if __name__ == "__main__":
    main()
