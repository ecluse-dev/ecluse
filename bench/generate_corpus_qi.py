#!/usr/bin/env python3
"""Generateur de corpus de quasi-identifiants (QI) annotes.  (P2-03a)

Mesure ce que `ecluse_reid` extrait d'un texte : profession de sante, lieu
(commune), age. Aucun detecteur n'est teste ici : c'est l'outil de mesure
(regle 5 de CLAUDE.md) qui manquait avant tout travail sur ces QI.

Trois corpus distincts, jamais fusionnes :
  - realiste     : comptes rendus plausibles, UNE personne
  - adversarial  : pieges (homonymes, lieux sans population, plusieurs lieux,
                   plusieurs ages, plusieurs personnes, formes de surface)
  - temoin       : aucun QI rattache a une personne, que des leurres

Format de sortie (celui de generate_corpus_flou.py, un champ en plus) :
  {"id": int, "text": str, "personnes": int,
   "entities": [{"type": "profession"|"lieu"|"age", "start": int, "end": int}]}

Conventions de span (a lire avant de comparer a une extraction) :
  - age        : chiffres + espace (ou espace insecable) + « ans » (« 94 ans »)
  - lieu       : le nom de la commune tel qu'ecrit, sans « a » ni « de »
  - profession : le terme de specialite ou de profession tel qu'ecrit
  - les professions HORS PERIMETRE d'`ecluse_reid` (infirmiere,
    kinesitherapeute...) apparaissent dans le texte mais ne sont PAS annotees :
    la bibliotheque ne les couvre pas (LIMITES.md § 7)

Toutes les valeurs sont synthetiques : personnes, textes et ages sont
inventes. Seuls les noms de communes sont reels (geographie publique) ; le
test `test_qi.py` verifie qu'ils existent dans l'asset de reference. Aucune
lecture de fichier externe a la generation.

Usage :
    python generate_corpus_qi.py --n 400 --seed 42 --out-dir .
"""

import argparse
import json
import random

from generate_corpus_flou import Doc, personne

# ---------------------------------------------------------------------------
# Vocabulaire
# ---------------------------------------------------------------------------

# Specialites et professions couvertes par ecluse_reid (formes courantes).
PROFESSIONS = ["pneumologue", "cardiologue", "dermatologue", "pédiatre",
               "psychiatre", "radiologue", "ophtalmologue", "gynécologue",
               "médecin généraliste", "chirurgien", "pharmacien",
               "pharmacienne", "sage-femme", "chirurgien-dentiste",
               "gastro-entérologue", "anesthésiste"]

# Formes de surface plus difficiles pour le meme referent : synonymes,
# graphies sans accent, majuscules, abreviations courantes.
PROFESSIONS_DURES = ["oto-rhino-laryngologiste", "ORL", "gastroentérologue",
                     "anesthésiste-réanimateur", "pédicure-podologue",
                     "ophtalmologiste", "pediatre", "CARDIOLOGUE", "gynéco",
                     "pneumo", "généraliste"]

# Professions de sante que la bibliotheque ne couvre pas : texte, jamais annote.
HORS_PERIMETRE = ["l'infirmière", "le kinésithérapeute", "l'orthophoniste",
                  "l'aide-soignante", "l'ergothérapeute", "la diététicienne"]

COMMUNES = ["Thionville", "Vesoul", "Besançon", "Dole", "Nantes", "Lille",
            "Brest", "Orléans", "Rennes", "Dijon", "Metz", "Nancy", "Limoges",
            "Poitiers", "Angers", "Rioz", "Champagnole", "Beaune", "Gray",
            "Luxeuil-les-Bains", "Montbéliard", "Belfort", "Lons-le-Saunier"]

# Noms portes par plusieurs communes : le lieu est ambigu.
COMMUNES_HOMONYMES = ["Saint-Denis", "Sainte-Colombe", "La Chapelle",
                      "Saint-Martin", "Beaulieu", "Saint-Aubin", "Le Pin",
                      "Héricourt"]

# Communes sans population dans les donnees de reference (Paris, Lyon,
# Marseille agreges ; Mayotte) : le lieu n'est pas evaluable.
COMMUNES_SANS_POPULATION = ["Paris", "Lyon", "Marseille", "Mamoudzou",
                            "Dzaoudzi", "Koungou"]

# Population legale nulle (villages detruits) : cas limite, F = 0.
COMMUNES_POPULATION_NULLE = ["Bezonvaux", "Fleury-devant-Douaumont"]

# Articles, tirets, apostrophes, accents : pieges de frontiere.
COMMUNES_FORMES = ["L'Isle-sur-le-Doubs", "Le Mans", "Saint-Jean-de-Luz",
                   "Villefranche-sur-Saône", "Aix-en-Provence",
                   "Boulogne-sur-Mer", "Châlons-en-Champagne", "Saint-Étienne",
                   "Les Sables-d'Olonne", "Mont-de-Marsan"]

# Mots courants qui sont aussi des noms de commune : leurres du temoin.
MOTS_COMMUNES = ["Orange", "Tours", "Nuits", "Plaine", "Pont", "Ville", "Mer"]

AGES_TOUTES_LETTRES = ["quatre-vingt-quatorze", "soixante-douze",
                       "quarante-sept", "trente et un", "cinquante-huit"]

NBSP = " "

# Tous les noms de communes utilises (le test les verifie dans l'asset).
TOUTES_COMMUNES = (COMMUNES + COMMUNES_HOMONYMES + COMMUNES_SANS_POPULATION
                   + COMMUNES_POPULATION_NULLE + COMMUNES_FORMES
                   + MOTS_COMMUNES)


# ---------------------------------------------------------------------------
# Fabriques de fragments
# ---------------------------------------------------------------------------

def cap(texte):
    return texte[0].upper() + texte[1:]


def age_valeur(rng, bas=22, haut=96):
    return rng.randint(bas, haut)


def ajoute_age(doc, age, sep=" "):
    return doc.ent(f"{age}{sep}ans", "age")


def intro(doc, rng):
    """Phrase d'ouverture neutre (sans QI)."""
    return doc.add(rng.choice([
        "Compte rendu d'entretien. ", "Note de suivi. ",
        "Relevé de la réunion de service. ", "Dossier en cours. "]))


def filler(doc, rng):
    """Phrase sans QI (ni profession couverte, ni lieu, ni age)."""
    return doc.add(rng.choice([
        " La situation est stable et le suivi reste à organiser.",
        " Un point sera fait lors de la prochaine réunion.",
        f" {cap(rng.choice(HORS_PERIMETRE))} de l'équipe assure le relais.",
        " Les documents ont été transmis à la direction.",
        f" Un contact sera pris avec {rng.choice(HORS_PERIMETRE)} avant la "
        f"fin du mois."]))


# ---------------------------------------------------------------------------
# Documents
# ---------------------------------------------------------------------------

def doc_realiste(rng):
    """Une personne ; profession+lieu+age, lieu+age, lieu seul,
    profession+lieu ou age seul. Formes courantes uniquement."""
    civ, prenom, nom, _ = personne(rng)
    d = Doc()
    intro(d, rng)
    variante = rng.randrange(5)
    commune = rng.choice(COMMUNES)
    if variante == 0:  # profession + lieu + age (Cas A)
        d.add(f"Le Dr {nom}, ").ent(rng.choice(PROFESSIONS), "profession")
        d.add(" à ").ent(commune, "lieu").add(", ")
        ajoute_age(d, age_valeur(rng, 30, 70)).add(", est en arrêt.")
    elif variante == 1:  # lieu + age (Cas B)
        d.add(f"{civ} {prenom} {nom}, ")
        ajoute_age(d, age_valeur(rng, 20, 96))
        d.add(", domicilié à ").ent(commune, "lieu").add(".")
    elif variante == 2:  # lieu seul
        d.add(f"{civ} {nom} réside à ").ent(commune, "lieu").add(".")
    elif variante == 3:  # profession + lieu
        d.add(f"{civ} {nom} est ").ent(rng.choice(PROFESSIONS), "profession")
        d.add(" à ").ent(commune, "lieu").add(".")
    else:  # age seul
        d.add(f"{civ} {nom}, ")
        ajoute_age(d, age_valeur(rng, 20, 96)).add(", est suivi par le service.")
    filler(d, rng)
    return d, 1


def doc_adversarial(rng):
    """Pieges ciblant l'extraction et l'estimation. Retourne (doc, personnes)."""
    civ, prenom, nom, _ = personne(rng)
    d = Doc()
    intro(d, rng)
    cas = rng.randrange(12)
    if cas == 0:  # commune homonyme
        d.add(f"{civ} {nom}, ")
        ajoute_age(d, age_valeur(rng)).add(", habite ")
        d.ent(rng.choice(COMMUNES_HOMONYMES), "lieu").add(".")
        personnes = 1
    elif cas == 1:  # lieu sans population
        d.add(f"Le Dr {nom}, ").ent(rng.choice(PROFESSIONS), "profession")
        d.add(" à ").ent(rng.choice(COMMUNES_SANS_POPULATION), "lieu")
        d.add(".")
        personnes = 1
    elif cas == 2:  # deux lieux, une personne
        d.add(f"{civ} {nom} habite ").ent(rng.choice(COMMUNES), "lieu")
        d.add(" et travaille à ").ent(rng.choice(COMMUNES), "lieu").add(".")
        personnes = 1
    elif cas == 3:  # deux ages, deux personnes
        d.add(f"{civ} {nom}, ")
        ajoute_age(d, age_valeur(rng, 60, 96))
        d.add(", vit avec sa fille de ")
        ajoute_age(d, age_valeur(rng, 25, 55)).add(".")
        personnes = 2
    elif cas == 4:  # profession sans lieu
        d.add(f"Le Dr {nom} est ").ent(rng.choice(PROFESSIONS), "profession")
        d.add(f" depuis longtemps ; {civ} {prenom} le remplace.")
        personnes = 2
    elif cas == 5:  # plusieurs personnes, chacune avec ses QI
        n = rng.randint(2, 3)
        for i in range(n):
            _, _, nom_i, _ = personne(rng)
            if i:
                d.add(" ")
            d.add(f"Le Dr {nom_i}, ")
            d.ent(rng.choice(PROFESSIONS), "profession").add(" à ")
            d.ent(rng.choice(COMMUNES), "lieu").add(", ")
            ajoute_age(d, age_valeur(rng, 30, 70)).add(".")
        personnes = n
    elif cas == 6:  # ages aux bornes de la pyramide (0 a 104 ans) et au-dela
        d.add(f"{civ} {nom}, ")
        ajoute_age(d, rng.choice([0, 1, 100, 103, 104, 105, 110]))
        d.add(", est hébergé à ").ent(rng.choice(COMMUNES), "lieu").add(".")
        personnes = 1
    elif cas == 7:  # formes de surface : espace insecable, toutes lettres
        d.add(f"{civ} {nom}, ")
        if rng.random() < 0.5:
            ajoute_age(d, age_valeur(rng), NBSP)
        else:
            d.ent(f"{rng.choice(AGES_TOUTES_LETTRES)} ans", "age")
        d.add(", vit à ").ent(rng.choice(COMMUNES), "lieu").add(".")
        personnes = 1
    elif cas == 8:  # professions : synonymes, graphies, abreviations
        d.add(f"Le Dr {nom}, ").ent(rng.choice(PROFESSIONS_DURES),
                                    "profession")
        d.add(" à ").ent(rng.choice(COMMUNES), "lieu").add(".")
        personnes = 1
    elif cas == 9:  # communes a article, tirets, apostrophes
        d.add(f"{civ} {nom}, ")
        ajoute_age(d, age_valeur(rng)).add(", demeure à ")
        d.ent(rng.choice(COMMUNES_FORMES), "lieu").add(".")
        personnes = 1
    elif cas == 10:  # population legale nulle
        d.add(f"{civ} {nom} serait né à ")
        d.ent(rng.choice(COMMUNES_POPULATION_NULLE), "lieu").add(".")
        personnes = 1
    else:  # profession hors perimetre, non annotee, avec lieu et age
        d.add(f"{cap(rng.choice(HORS_PERIMETRE))} {nom}, ")
        ajoute_age(d, age_valeur(rng, 25, 60)).add(", travaille à ")
        d.ent(rng.choice(COMMUNES), "lieu").add(".")
        personnes = 1
    filler(d, rng)
    return d, personnes


def doc_temoin(rng):
    """Aucun QI rattache a une personne : durees, quantites, mots communs qui
    sont aussi des communes, professions hors perimetre, lieu de reunion."""
    d = Doc()
    intro(d, rng)
    cas = rng.randrange(6)
    if cas == 0:
        d.add(f"Le contrat est signé pour {rng.randint(2, 9)} ans, "
              f"renouvelable.")
    elif cas == 1:
        d.add(f"Le service existe depuis {rng.randint(3, 30)} ans ; la "
              f"dernière révision date d'il y a {rng.randint(2, 12)} ans.")
    elif cas == 2:
        mot = rng.choice(MOTS_COMMUNES)
        d.add(f"{mot} figure parmi les points abordés lors de la réunion.")
    elif cas == 3:
        d.add(f"{rng.choice(['Tours', 'Nuits'])} de garde : le planning est "
              f"à revoir.")
    elif cas == 4:
        d.add(f"{cap(rng.choice(HORS_PERIMETRE))} a rendu son rapport sur "
              f"{rng.randint(3, 40)} dossiers.")
    else:  # lieu de reunion, sans lien avec une personne
        d.add(f"La réunion du CSE aura lieu à {rng.choice(COMMUNES)}.")
    return d, 0


# ---------------------------------------------------------------------------

FABRIQUES = [("realiste", doc_realiste), ("adversarial", doc_adversarial),
             ("temoin", doc_temoin)]


def construit(nom, n, seed):
    """Les n documents du corpus `nom`, deterministes pour (nom, n, seed)."""
    factory = dict(FABRIQUES)[nom]
    # Un RNG par corpus : ajouter des documents a l'un ne decale pas les autres.
    rng = random.Random(f"{seed}:qi:{nom}")
    docs = []
    for i in range(n):
        doc, personnes = factory(rng)
        built = doc.build(i)
        built["personnes"] = personnes
        docs.append(built)
    return docs


def ecrit(path, docs):
    with open(path, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")


def stats(docs):
    counts, chars = {}, {}
    for d in docs:
        for e in d["entities"]:
            counts[e["type"]] = counts.get(e["type"], 0) + 1
            chars[e["type"]] = chars.get(e["type"], 0) + e["end"] - e["start"]
    return counts, chars


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=400, help="documents par corpus")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out-dir", default=".")
    args = ap.parse_args()

    for nom, _ in FABRIQUES:
        docs = construit(nom, args.n, args.seed)
        path = f"{args.out_dir}/corpus_qi_{nom}.jsonl"
        ecrit(path, docs)
        counts, chars = stats(docs)
        multi = sum(1 for d in docs if d["personnes"] >= 2)
        print(f"{path} : {len(docs)} documents, {sum(counts.values())} QI, "
              f"{multi} documents de plusieurs personnes")
        for t in sorted(counts):
            print(f"    {t:12s} {counts[t]:5d} QI  {chars[t]:6d} caractères")
        if not counts:
            print("    (aucun QI — corpus témoin, par construction)")


if __name__ == "__main__":
    main()
