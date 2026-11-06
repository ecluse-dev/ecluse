#!/usr/bin/env python3
"""Generateur du corpus de pathologies annote (P2-112).

Sert a mesurer un futur extracteur de pathologies (quasi-identifiant de
`agent/specs/P2-07.md`) AVANT de l'ecrire (regle 5). Deux corpus, jamais
fusionnes :

  indices : transmissions ou une personne inventee est dite atteinte d'une
            ou deux pathologies ; chaque mention est annotee avec sa
            categorie et son systeme
  temoin  : memes cadres, mots de pathologie employes SANS personne malade
            (nom d'un service ou d'un reseau, sens figure) -> faux positifs

**Provisoire** : les mentions, categories et systemes viennent de la table
maison `agent/specs/P2-94-table.md` § 3, PAS ENCORE VALIDEE cliniquement
(P2-110). Le corpus est a regenerer si la table change. Les maladies rares
prennent la categorie « maladie rare » sans code Orphanet : la categorie
Orphanet fine est lue par `RareDiseaseCatalog` cote Dart, pas ici.

Format :
  {"id": int, "text": str,
   "pathologies": [{"start": int, "end": int, "mention": str,
                    "categorie": str, "systeme": str}]}

Toutes les valeurs sont synthetiques ; les personnes sont inventees.

Usage :
    python generate_corpus_pathologies.py --n 300 --seed 42 --out-dir .
"""

import argparse
import json
import random

# (systeme, categorie abregee, mentions) : agent/specs/P2-94-table.md § 3.
TABLE = [
    ("neurologique", "accident vasculaire cérébral invalidant",
     ["AVC", "accident vasculaire cérébral", "hémiplégie séquellaire"]),
    ("neurologique", "maladie d'Alzheimer et autres démences",
     ["maladie d'Alzheimer", "démence à corps de Lewy"]),
    ("neurologique", "maladie de Parkinson",
     ["maladie de Parkinson"]),
    ("neurologique", "sclérose en plaques", ["sclérose en plaques"]),
    ("neurologique", "affections neurologiques graves, épilepsie grave",
     ["épilepsie"]),
    ("neurologique", "paraplégie", ["paraplégie", "tétraplégie"]),
    ("psychiatrique", "affections psychiatriques de longue durée",
     ["schizophrénie", "trouble bipolaire", "dépression récurrente"]),
    ("cardio-vasculaire", "insuffisance cardiaque grave, troubles du rythme",
     ["insuffisance cardiaque", "fibrillation auriculaire"]),
    ("cardio-vasculaire", "maladie coronaire",
     ["infarctus du myocarde", "angor"]),
    ("respiratoire", "insuffisance respiratoire chronique grave",
     ["BPCO", "insuffisance respiratoire chronique"]),
    ("digestif et hépatique", "rectocolite hémorragique et maladie de Crohn",
     ["maladie de Crohn", "rectocolite hémorragique"]),
    ("digestif et hépatique", "maladies chroniques du foie et cirrhoses",
     ["cirrhose", "hépatite C"]),
    ("métabolique", "diabète de type 1 et de type 2",
     ["diabète de type 1", "diabète de type 2"]),
    ("rénal", "néphropathie chronique grave",
     ["insuffisance rénale chronique"]),
    ("hématologique", "hémoglobinopathies", ["drépanocytose", "thalassémie"]),
    ("hématologique", "hémophilies et affections graves de l'hémostase",
     ["hémophilie"]),
    ("immunitaire et infectieux",
     "déficit immunitaire primitif grave, infection par le VIH",
     ["infection par le VIH"]),
    ("immunitaire et infectieux", "tuberculose active", ["tuberculose"]),
    ("rhumatologique", "polyarthrite rhumatoïde évolutive",
     ["polyarthrite rhumatoïde"]),
    ("rhumatologique", "vascularites, lupus, sclérodermie systémique",
     ["lupus", "sclérodermie"]),
    ("oncologique", "tumeurs malignes",
     ["cancer du sein", "cancer du poumon", "lymphome", "leucémie"]),
    ("génétique", "mucoviscidose", ["mucoviscidose"]),
    ("transplantation", "suites de transplantation d'organe",
     ["greffe de rein"]),
]

RARES = ["maladie de Huntington", "sclérose latérale amyotrophique",
         "maladie de Wilson", "myopathie de Duchenne"]

PRENOMS_F = ["Odile", "Claire", "Nadia", "Sophie", "Agnès", "Inès",
             "Mireille", "Hélène"]
PRENOMS_H = ["Bernard", "Karim", "Julien", "Thierry", "Marc", "Rémi",
             "Antoine", "Pascal"]
NOMS = ["Marchetti", "Verdier", "Lambert", "Benali", "Roussel", "Faure",
        "Girardot", "Perrin", "Chevalier", "Bouvier"]
CADRES = ["Transmission. ", "Note au dossier. ", "Compte rendu de réunion. "]
SUITES_F = [" Elle a été reçue en entretien ce matin.",
            " Un rendez-vous de suivi est prévu.",
            " Sa famille a été informée."]
SUITES_H = [" Il a été reçu en entretien ce matin.",
            " Un rendez-vous de suivi est prévu.",
            " Sa famille a été informée."]

# Temoin : mots de pathologie sans personne atteinte.
TEMOINS = [
    "Réunion du réseau diabète de la Haute-Saône jeudi à 14 h.",
    "Le service d'oncologie déménage au deuxième étage.",
    "L'unité Alzheimer accueille deux nouveaux soignants.",
    "Formation sur l'épilepsie proposée à toute l'équipe.",
    "Le projet est devenu un cancer pour l'équipe administrative.",
    "La sclérose de l'organisation freine les nouveaux projets.",
    "Journée mondiale de la sclérose en plaques : stand dans le hall.",
    "Affiche de prévention de l'AVC posée en salle d'attente.",
    "Le laboratoire de cardiologie change de numéro.",
    "Colloque régional sur la mucoviscidose le mois prochain.",
]

ENTREES = [(s, c, m) for s, c, ms in TABLE for m in ms] + \
    [("maladie rare", "maladie rare", m) for m in RARES]


class Doc:
    """Construit un texte en enregistrant les offsets a l'insertion."""

    def __init__(self):
        self.parts, self.pathologies, self.length = [], [], 0

    def add(self, text):
        self.parts.append(text)
        self.length += len(text)
        return self

    def pathologie(self, systeme, categorie, mention):
        start = self.length
        self.add(mention)
        self.pathologies.append({"start": start, "end": self.length,
                                 "mention": mention, "categorie": categorie,
                                 "systeme": systeme})
        return self

    def text(self):
        return "".join(self.parts)


def doc_indices(rng):
    d = Doc()
    feminin = rng.random() < 0.5
    prenom = rng.choice(PRENOMS_F if feminin else PRENOMS_H)
    civ = "Mme" if feminin else "M."
    d.add(rng.choice(CADRES)).add(f"{civ} {prenom} {rng.choice(NOMS)}")
    atteint = "atteinte" if feminin else "atteint"
    e1, e2 = rng.sample(ENTREES, 2)
    forme = rng.randrange(3)
    if forme == 0:
        d.add(f", {atteint} de ").pathologie(*e1).add(".")
    elif forme == 1:
        d.add(", suivi" + ("e" if feminin else "") + " pour ").pathologie(*e1)
        d.add(" depuis plusieurs années.")
    else:
        d.add(", antécédents : ").pathologie(*e1).add(" et ").pathologie(*e2)
        d.add(".")
    d.add(rng.choice(SUITES_F if feminin else SUITES_H))
    return d


def doc_temoin(rng):
    d = Doc()
    d.add(rng.choice(CADRES))
    for phrase in rng.sample(TEMOINS, rng.randint(1, 2)):
        d.add(phrase).add(" ")
    d.add("Aucun résident n'est concerné par cette note.")
    return d


FABRIQUES = [("indices", doc_indices), ("temoin", doc_temoin)]


def construit(nom, n, seed):
    """Un generateur par corpus : ajouter des documents ne decale pas les
    premiers."""
    rng = random.Random(f"{seed}-pathologies-{nom}")
    fabrique = dict(FABRIQUES)[nom]
    sortie = []
    for i in range(n):
        d = fabrique(rng)
        sortie.append({"id": i, "text": d.text(),
                       "pathologies": d.pathologies})
    return sortie


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--n", type=int, default=300)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out-dir", default=".")
    a = p.parse_args()
    for nom, _ in FABRIQUES:
        docs = construit(nom, a.n, a.seed)
        chemin = f"{a.out_dir}/corpus_pathologies_{nom}.jsonl"
        with open(chemin, "w", encoding="utf-8") as f:
            for d in docs:
                f.write(json.dumps(d, ensure_ascii=False) + "\n")
        nb = sum(len(d["pathologies"]) for d in docs)
        print(f"{chemin} : {len(docs)} documents, {nb} mentions annotées")


if __name__ == "__main__":
    main()
