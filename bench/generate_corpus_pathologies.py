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
  formes_libres : formes que P2-125/126 ne couvrent pas (« non
            diabetique », « DT2 », « diabete : non », « BPCO ? a eliminer »,
            fautes), une forme par document, nommee dans le champ « forme »
            (P2-129, mesure seulement)
  variantes : une forme adjectivale annotee (« diabetique », « dialysee »)
            et souvent une negation NON annotee (« pas de BPCO connu »,
            « aucun antecedent d'epilepsie ») (P2-126)

Les mentions, categories et systemes viennent de la table maison
`agent/specs/P2-94-table.md` § 3, validee cliniquement par le mainteneur
(P2-110, 7 novembre 2026). Le corpus est a regenerer si la table change. Les maladies rares
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

ENTREES_TABLE = [(s, c, m) for s, c, ms in TABLE for m in ms] + [
    # Mentions de la table de P2-94 absentes des indices, utiles aux
    # variantes (P2-126).
    ("métabolique", "diabète de type 1 et de type 2", "diabète"),
    ("rénal", "néphropathie chronique grave", "dialyse"),
    ("immunitaire et infectieux",
     "déficit immunitaire primitif grave, infection par le VIH",
     "séropositivité"),
]
ENTREES = [(s, c, m) for s, c, ms in TABLE for m in ms] + \
    [("maladie rare", "maladie rare", m) for m in RARES]


class Doc:
    """Construit un texte en enregistrant les offsets a l'insertion."""

    forme = None

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


# Formes adjectivales : (masculin, feminin, mention de la table dont elles
# relevent). P2-126.
ADJECTIFS = [
    ("diabétique", "diabétique", "diabète"),
    ("épileptique", "épileptique", "épilepsie"),
    ("parkinsonien", "parkinsonienne", "maladie de Parkinson"),
    ("hémophile", "hémophile", "hémophilie"),
    ("schizophrène", "schizophrène", "schizophrénie"),
    ("paraplégique", "paraplégique", "paraplégie"),
    ("tétraplégique", "tétraplégique", "tétraplégie"),
    ("dialysé", "dialysée", "dialyse"),
    ("cirrhotique", "cirrhotique", "cirrhose"),
    ("drépanocytaire", "drépanocytaire", "drépanocytose"),
    ("séropositif", "séropositive", "séropositivité"),
    ("bipolaire", "bipolaire", "trouble bipolaire"),
]

# Negations : la pathologie est citee pour dire qu'elle est ABSENTE. Rien a
# annoter : ce n'est pas un indice sur la personne.
NEGATIONS = [
    "Pas de {m} connu.", "Aucun antécédent de {m}.", "Absence de {m}.",
    "Sans antécédent de {m} dans la famille.", "Pas d'argument pour une {m}.",
]
NEGATIONS_MENTIONS = ["diabète", "épilepsie", "BPCO", "tuberculose",
                      "cirrhose", "drépanocytose"]


def _categorie(mention):
    for s, c, m in ENTREES_TABLE:
        if m == mention:
            return s, c
    raise KeyError(mention)


def doc_variantes(rng):
    """Une forme adjectivale annotee, et parfois une negation non annotee."""
    d = Doc()
    feminin = rng.random() < 0.5
    prenom = rng.choice(PRENOMS_F if feminin else PRENOMS_H)
    civ = "Mme" if feminin else "M."
    d.add(rng.choice(CADRES)).add(f"{civ} {prenom} {rng.choice(NOMS)}, ")
    masc, fem, mention = rng.choice(ADJECTIFS)
    systeme, categorie = _categorie(mention)
    d.pathologie(systeme, categorie, fem if feminin else masc)
    d.add(rng.choice([", est arrivé" + ("e" if feminin else "") +
                      " ce matin.", ", sollicite un rendez-vous."]))
    if rng.random() < 0.7:
        neg = rng.choice(NEGATIONS_MENTIONS)
        gabarit = rng.choice(NEGATIONS)
        if "une {m}" in gabarit and neg in ("diabète", "BPCO"):
            gabarit = "Pas de {m} connu."
        phrase = gabarit.format(m=neg).replace(" de é", " d'é")
        d.add(" ").add(phrase)
    return d


# P2-129. (forme, annotee) : une pathologie DE LA PERSONNE est annotee ; une
# negation, une suspicion ou une exclusion ne l'est pas. Les documents
# tournent sur cette liste (document i -> forme i % len) : chaque forme a le
# meme poids et ajouter des documents ne decale pas les premiers.
FORMES_LIBRES = [
    "non_adjectif", "sigle_dt2", "deux_points_non", "a_eliminer",
    "suspicion", "atcd_deux_points", "faute_diabete", "faute_epilepsie",
    "exclu_apres", "ni_apres",
]
# Formes annotees : (forme, mention ecrite, mention de la table).
FORMES_LIBRES_ANNOTEES = {
    "sigle_dt2": ("DT2", "diabète de type 2"),
    "atcd_deux_points": ("diabète de type 2", "diabète de type 2"),
    "faute_diabete": ("diabete", "diabète"),
    "faute_epilepsie": ("épilépsie", "épilepsie"),
}


def doc_formes_libres(rng, i):
    forme = FORMES_LIBRES[i % len(FORMES_LIBRES)]
    d = Doc()
    d.forme = forme
    feminin = rng.random() < 0.5
    prenom = rng.choice(PRENOMS_F if feminin else PRENOMS_H)
    civ = "Mme" if feminin else "M."
    d.add(rng.choice(CADRES)).add(f"{civ} {prenom} {rng.choice(NOMS)}")
    atteint = "atteinte" if feminin else "atteint"
    if forme == "non_adjectif":
        d.add(", non " + rng.choice(["diabétique", "épileptique",
                                     "dialysé" if not feminin else "dialysée"])
              + ".")
    elif forme == "deux_points_non":
        d.add(". " + rng.choice(["Diabète", "BPCO", "Épilepsie"]) + " : non.")
    elif forme == "a_eliminer":
        d.add(". " + rng.choice(["BPCO", "Tuberculose", "Lupus"])
              + " ? à éliminer.")
    elif forme == "suspicion":
        d.add(". Suspicion de " + rng.choice(["BPCO", "cirrhose", "lupus"])
              + ", examens en cours.")
    elif forme == "exclu_apres":
        d.add(". " + rng.choice(["Diabète", "Tuberculose", "Cirrhose"])
              + " exclu" + rng.choice(["", "e"]) + " au dernier bilan.")
    elif forme == "ni_apres":
        d.add(". Ni " + rng.choice(["diabète", "cirrhose"]) + " ni "
              + rng.choice(["BPCO", "lupus"]) + " connus.")
    else:
        ecrit, de_table = FORMES_LIBRES_ANNOTEES[forme]
        systeme, categorie = _categorie(de_table)
        if forme == "sigle_dt2":
            d.add(f", {atteint} de ").pathologie(systeme, categorie, ecrit)
            d.add(".")
        elif forme == "atcd_deux_points":
            d.add(". ATCD : ").pathologie(systeme, categorie, ecrit).add(".")
        elif forme == "faute_diabete":
            d.add(f", {atteint} de ").pathologie(systeme, categorie, ecrit)
            d.add(".")
        else:
            d.add(f", suivi{'e' if feminin else ''} pour ")
            d.pathologie(systeme, categorie, ecrit).add(" depuis 2019.")
    d.add(rng.choice(SUITES_F if feminin else SUITES_H))
    return d


FABRIQUES = [("indices", doc_indices), ("temoin", doc_temoin),
             ("variantes", doc_variantes),
             ("formes_libres", doc_formes_libres)]


def construit(nom, n, seed):
    """Un generateur par corpus : ajouter des documents ne decale pas les
    premiers."""
    rng = random.Random(f"{seed}-pathologies-{nom}")
    fabrique = dict(FABRIQUES)[nom]
    sortie = []
    for i in range(n):
        d = fabrique(rng, i) if nom == "formes_libres" else fabrique(rng)
        doc = {"id": i, "text": d.text(), "pathologies": d.pathologies}
        if d.forme:
            doc["forme"] = d.forme
        sortie.append(doc)
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
