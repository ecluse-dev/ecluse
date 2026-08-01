#!/usr/bin/env python3
"""Generateur de corpus pour les entites floues d'Ecluse.  (v2)

CHANGEMENTS v2 — corrige trois defauts de conception de la v1 qui
faussaient la mesure du 31/07 :

  1. ACCENTS. La v1 ne contenait aucun caractere accentue. Le detecteur de
     dates cherche « ne le » avec accent ; le corpus ecrivait « ne le ».
     Resultat : 0 detection sur 165 dates, entierement imputable au corpus.
  2. CASSE DES ETABLISSEMENTS. La v1 ecrivait « clinique du Parc » en
     minuscules ; le detecteur exige une majuscule initiale. Le rappel
     mesure etait donc artificiellement bas.
  3. LEURRES DU TEMOIN. La v1 classait « contact@example.fr » et
     « EHPAD Marie Curie » comme leurres. Les masquer est en realite le bon
     comportement : un nom d'etablissement est un quasi-identifiant. Ces
     leurres produisaient 142 faux positifs fictifs sur 281.

Trois corpus distincts, jamais fusionnes :
  - realiste     : documents plausibles -> le niveau de service reel
  - adversarial  : pieges denses        -> les angles morts
  - temoin       : zero entite, que des leurres LEGITIMES -> sur-masquage pur

Format de sortie :
  {"id": int, "text": str, "entities": [{"type": str, "start": int, "end": int}]}

Toutes les valeurs sont synthetiques. Aucune lecture de fichier externe.
Telephones : plages ARCEP reservees a la fiction. Emails : example.fr/.com.

Usage :
    python generate_corpus_flou.py --n 400 --seed 42 --out-dir .
"""

import argparse
import json
import random

# ---------------------------------------------------------------------------
# Constructeur : enregistre les offsets a l'insertion, jamais par recherche
# a posteriori (qui casse des qu'une valeur apparait deux fois).
# ---------------------------------------------------------------------------


class Doc:
    def __init__(self):
        self.parts = []
        self.entities = []
        self.length = 0

    def add(self, text):
        self.parts.append(text)
        self.length += len(text)
        return self

    def ent(self, text, etype):
        start = self.length
        self.parts.append(text)
        self.length += len(text)
        self.entities.append({"type": etype, "start": start, "end": self.length})
        return self

    def build(self, doc_id):
        return {
            "id": doc_id,
            "text": "".join(self.parts),
            "entities": sorted(self.entities, key=lambda e: e["start"]),
        }


# ---------------------------------------------------------------------------
# Vocabulaire synthetique — accentue
# ---------------------------------------------------------------------------

PRENOMS_F = ["Sophie", "Nathalie", "Élodie", "Laure", "Sandrine", "Céline",
             "Karine", "Aurélie", "Camille"]
PRENOMS_M = ["Julien", "Thomas", "Marc", "Antoine", "Guillaume", "Olivier",
             "Vincent", "Frédéric", "Camille"]
PRENOMS_FR = PRENOMS_F + PRENOMS_M

# Prenoms hors gazetteer FR classique : piege de rappel
PRENOMS_NON_FR = ["Aïcha", "Ibrahim", "Krzysztof", "Mei-Ling", "Souleymane",
                  "Yaroslav"]

NOMS = ["Verdier", "Fabrier", "Delaunay", "Chevrier", "Marchand", "Aubry",
        "Vasseur", "Gauthier", "Perrot", "Reynaud", "Mérieux", "Lefèvre"]

# Patronymes qui sont aussi des mots courants : piege de precision
NOMS_AMBIGUS = ["Loyer", "Boulanger", "Petit", "Rose", "Berger", "Meunier",
                "Charpentier", "Legrand", "Leblanc", "Lemoine"]

CIVILITES_F = ["Madame", "Mademoiselle", "Mme"]
CIVILITES_M = ["Monsieur", "M."]
TITRES = ["Dr", "Pr", "Me"]


def personne(rng):
    """(civilite, prenom, nom, genre) avec accord de genre.

    L'accord evite un artefact de generation qui penaliserait injustement
    un NER statistique.
    """
    genre = rng.choice(["f", "m"])
    prenom = rng.choice(PRENOMS_F if genre == "f" else PRENOMS_M)
    civ = rng.choice(CIVILITES_F if genre == "f" else CIVILITES_M)
    return civ, prenom, rng.choice(NOMS), genre


VOIES = ["12 Rue des Quatre Vents", "7 Impasse des Charmilles",
         "3 Route de Vellexon", "45 Avenue du Général Leclerc",
         "8 Chemin des Vignes", "21 Place du Marché"]

COMMUNES = [("70160", "PORT SUR SAONE"), ("70180", "DAMPIERRE SUR SALON"),
            ("70000", "VESOUL"), ("25000", "BESANCON"),
            ("39100", "DOLE"), ("21000", "DIJON")]

# Communes a article, tirets ou accents : piege de frontiere
COMMUNES_DURES = [("25250", "L'Isle-sur-le-Doubs"), ("70400", "Héricourt"),
                  ("39300", "Champagnole"), ("21200", "Beaune"),
                  ("70190", "Rioz")]

# Etablissements avec majuscule initiale, comme dans un document reel.
ETABLISSEMENTS = ["CH de Vesoul", "EHPAD Les Tilleuls", "ESAT du Val",
                  "SSIAD de Gray", "Clinique du Parc", "IME La Source",
                  "MAS des Coteaux", "Centre Hospitalier de Dole"]

# Etablissements portant un nom de personne : le piege de TYPE.
# Doivent etre annotes « etablissement », pas « nom ».
ETABLISSEMENTS_EPONYMES = ["Hôpital Robert Debré", "Résidence Simone Veil",
                           "Clinique Pasteur", "EHPAD Marie Curie",
                           "Lycée Louis Pergaud", "Centre Jean Moulin"]

# Odonymes portant un nom de personne : font partie de l'adresse, pas du nom.
ODONYMES_EPONYMES = ["12 Rue Victor Hugo", "5 Place Jean Jaurès",
                     "30 Boulevard Aristide Briand"]

# Sigles metier : ne doivent JAMAIS etre masques
SIGLES_METIER = ["CSE", "CCAS", "RCP", "APA", "MSP", "EVA", "AGGIR", "MDPH",
                 "CVS", "COPIL", "CHSCT", "GIR"]

# Eponymes medicaux : ne doivent JAMAIS etre masques comme des personnes
EPONYMES_MEDICAUX = ["maladie de Parkinson", "syndrome de Guillain-Barré",
                     "manœuvre de Heimlich", "échelle de Glasgow",
                     "test de Romberg", "signe de Babinski",
                     "maladie d'Alzheimer", "score de Braden",
                     "grille de Katz", "syndrome de Korsakoff"]

MOIS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet",
        "août", "septembre", "octobre", "novembre", "décembre"]

PREFIXES_TEL_FICTION = ["0199 00", "0261 91", "0353 01", "0465 71",
                        "0536 49", "0639 98", "0700 91"]

SANS_ACCENT = str.maketrans("àâäéèêëîïôöùûüçÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ",
                            "aaaeeeeiioouuucAAAEEEEIIOOUUUC")


# ---------------------------------------------------------------------------
# Fabriques de valeurs
# ---------------------------------------------------------------------------


def tel(rng, style="espace"):
    num = rng.choice(PREFIXES_TEL_FICTION).replace(" ", "") + f"{rng.randint(0, 9999):04d}"
    if style == "espace":
        return " ".join(num[i:i + 2] for i in range(0, 10, 2))
    if style == "point":
        return ".".join(num[i:i + 2] for i in range(0, 10, 2))
    if style == "colle":
        return num
    if style == "international":
        return "+33 " + num[1] + " " + " ".join(num[i:i + 2] for i in range(2, 10, 2))
    return num


def email(rng, prenom, nom, style="simple"):
    p = prenom.lower().translate(SANS_ACCENT)
    n = nom.lower().translate(SANS_ACCENT).replace("-", "").replace("'", "")
    if style == "tag":
        return f"{p}.{n}+dossier@example.fr"
    if style == "sousdomaine":
        return f"{p}.{n}@service.example.com"
    if style == "initiale":
        return f"{p[0]}{n}@example.fr"
    return f"{p}.{n}@example.fr"


def date_naissance(rng, style="slash"):
    j, m, a = rng.randint(1, 28), rng.randint(1, 12), rng.randint(1930, 2005)
    if style == "point":
        return f"{j:02d}.{m:02d}.{a}"
    if style == "iso":
        return f"{a}-{m:02d}-{j:02d}"
    if style == "litteral":
        return f"{j} {MOIS[m - 1]} {a}"
    return f"{j:02d}/{m:02d}/{a}"


def ancrage_naissance(rng, genre):
    """Formulation introduisant une date de naissance.

    La v1 n'utilisait que « ne le » / « nee le » sans accent, ce qui rendait
    les 165 dates du corpus invisibles au detecteur.
    """
    return rng.choice([
        f"né{'e' if genre == 'f' else ''} le ",
        "date de naissance : ",
        "DDN : ",
    ])


def adresse_une_ligne(rng, dures=False):
    voie = rng.choice(VOIES)
    cp, com = rng.choice(COMMUNES_DURES if dures else COMMUNES)
    return f"{voie}, {cp} {com}"


def adresse_deux_lignes(rng, dures=False):
    voie = rng.choice(VOIES)
    cp, com = rng.choice(COMMUNES_DURES if dures else COMMUNES)
    return f"{voie}\n{cp} {com}"


# ---------------------------------------------------------------------------
# CORPUS REALISTE
# ---------------------------------------------------------------------------


def doc_realiste(rng):
    d = Doc()
    civ, prenom, nom, genre = personne(rng)
    variante = rng.randint(0, 4)

    if variante == 0:  # compte rendu de reunion
        d.add("Compte rendu de la réunion du ").add(rng.choice(SIGLES_METIER))
        d.add(" du 14/03/2026.\n\nParticipants :\n- ")
        d.ent(f"{civ} {prenom} {nom}", "nom")
        d.add(", référent numérique\n- ")
        d.ent("{} {} {}".format(*personne(rng)[:3]), "nom")
        d.add("\n\nÉtablissement concerné : ")
        d.ent(rng.choice(ETABLISSEMENTS), "etablissement")
        d.add("\nContact : ").ent(email(rng, prenom, nom), "email")
        d.add(" / ").ent(tel(rng), "telephone")
        d.add("\n\nLe point sur le ").add(rng.choice(SIGLES_METIER))
        d.add(" a été reporté à la prochaine séance.\n")

    elif variante == 1:  # courrier d'admission
        accord = "e" if genre == "f" else ""
        d.add("Objet : admission\n\n").ent(f"{civ} {prenom} {nom}", "nom")
        d.add(", ").add(ancrage_naissance(rng, genre))
        d.ent(date_naissance(rng), "date_naissance")
        d.add(f",\ndomicilié{accord} ").ent(adresse_deux_lignes(rng), "adresse")
        d.add(f",\nest admis{accord} à l'")
        d.ent(rng.choice(ETABLISSEMENTS), "etablissement")
        d.add(" à compter du 05/09/2026.\n\nLe dossier mentionne une ")
        d.add(rng.choice(EPONYMES_MEDICAUX))
        d.add(" suivie depuis 2019.\n")

    elif variante == 2:  # note de transmission
        d.add("Transmission du ").add(f"{rng.randint(1, 28):02d}/07/2026")
        d.add(" — équipe de nuit\n\nVisite de ")
        d.ent(f"{rng.choice(TITRES)} {nom}", "nom")
        d.add(" ce matin. Bilan ").add(rng.choice(EPONYMES_MEDICAUX))
        d.add(" stable.\nLa famille (").ent(tel(rng, "point"), "telephone")
        d.add(") a été prévenue.\nTransfert prévu vers l'")
        d.ent(rng.choice(ETABLISSEMENTS_EPONYMES), "etablissement")
        d.add(".\nÀ revoir en ").add(rng.choice(SIGLES_METIER))
        d.add(" la semaine prochaine.\n")

    elif variante == 3:  # contrat de travail
        accord = "e" if genre == "f" else ""
        d.add("Entre les soussignés :\n\nL'association gestionnaire de l'")
        d.ent(rng.choice(ETABLISSEMENTS), "etablissement")
        d.add(",\n\net ").ent(f"{civ} {prenom} {nom}", "nom")
        d.add(", ").add(ancrage_naissance(rng, genre))
        d.ent(date_naissance(rng, "litteral"), "date_naissance")
        d.add(",\ndemeurant ").ent(adresse_une_ligne(rng), "adresse")
        d.add(",\njoignable au ").ent(tel(rng), "telephone")
        d.add(".\n\nIl est convenu ce qui suit.\n")

    else:  # courriel professionnel
        d.add("De : ").ent(email(rng, prenom, nom), "email")
        d.add("\nÀ : ")
        d.ent(email(rng, *personne(rng)[1:3], "sousdomaine"), "email")
        d.add("\nObjet : dossier en cours\n\nBonjour,\n\nComme convenu avec ")
        d.ent("{} {} {}".format(*personne(rng)[:3]), "nom")
        d.add(", je vous transmets les éléments concernant l'")
        d.ent(rng.choice(ETABLISSEMENTS), "etablissement")
        d.add(".\nLe rendez-vous du 12/09/2026 est confirmé.\n\nCordialement.\n")

    return d


# ---------------------------------------------------------------------------
# CORPUS ADVERSARIAL
# ---------------------------------------------------------------------------


def doc_adversarial(rng):
    d = Doc()
    variante = rng.randint(0, 6)

    if variante == 0:  # sans civilite, ordre inverse, capitales
        nom, prenom = rng.choice(NOMS), rng.choice(PRENOMS_FR)
        d.add("Dossier suivi par ").ent(f"{nom.upper()} {prenom}", "nom")
        d.add(".\nLe référent est ").ent(f"{prenom} {nom}", "nom")
        d.add(", joignable en interne.\nNote transmise à ")
        d.ent(f"{prenom.upper()} {nom.upper()}", "nom")
        d.add(" pour suite à donner.\n")

    elif variante == 1:  # patronymes ambigus + eponymes en leurre
        nom = rng.choice(NOMS_AMBIGUS)
        civ, prenom, _, _ = personne(rng)
        d.add(civ + " ").ent(f"{prenom} {nom}", "nom")
        d.add(" présente une ").add(rng.choice(EPONYMES_MEDICAUX))
        d.add(".\nLe bilan a été réalisé à l'")
        d.ent(rng.choice(ETABLISSEMENTS_EPONYMES), "etablissement")
        d.add(".\nLe montant du loyer reste inchangé.\n")

    elif variante == 2:  # initiales, particules, composes
        d.add("Présent : ")
        d.ent(f"{rng.choice(PRENOMS_FR)[0]}. {rng.choice(NOMS)}", "nom")
        d.add("\nExcusé : ").ent("Monsieur Jean de La Fontaine", "nom")
        d.add("\nSuppléant : ")
        d.ent(f"{rng.choice(PRENOMS_FR)}-{rng.choice(PRENOMS_FR)} "
              f"{rng.choice(NOMS)}-{rng.choice(NOMS)}", "nom")
        d.add("\n")

    elif variante == 3:  # prenoms non francais
        d.add("Le dossier de ")
        d.ent(f"{rng.choice(PRENOMS_NON_FR)} {rng.choice(NOMS)}", "nom")
        d.add(" est incomplet.\nContacter ")
        d.ent(f"{rng.choice(PRENOMS_NON_FR)} {rng.choice(NOMS)}", "nom")
        d.add(" au ").ent(tel(rng, "international"), "telephone")
        d.add(".\n")

    elif variante == 4:  # adresses dures
        d.add("Adresse de facturation :\n")
        d.ent(adresse_deux_lignes(rng, dures=True), "adresse")
        d.add("\n\nAdresse du chantier :\n")
        cp, com = rng.choice(COMMUNES)
        d.ent(f"{rng.choice(VOIES)}\n{cp} {com} CEDEX 9", "adresse")
        d.add("\n\nMontant : 70000 euros de travaux.\nRéférence dossier 21000.\n")

    elif variante == 5:  # formats degrades contacts et dates
        prenom, nom = rng.choice(PRENOMS_FR), rng.choice(NOMS)
        genre = "f" if prenom in PRENOMS_F else "m"
        d.add("Coordonnées :\n").ent(tel(rng, "colle"), "telephone")
        d.add("\n").ent(email(rng, prenom, nom, "tag"), "email")
        d.add("\n").add(ancrage_naissance(rng, genre))
        d.ent(date_naissance(rng, "iso"), "date_naissance")
        d.add("\nÉchéance de la facture : 05/08/2026\n")
        d.add("Date de livraison : 05/07/2026\n")

    else:  # personnes DANS des lieux : piege de TYPE, pas de detection
        d.add("Réunion tenue à l'")
        d.ent(rng.choice(ETABLISSEMENTS_EPONYMES), "etablissement")
        d.add(",\nsituée ").ent(rng.choice(ODONYMES_EPONYMES), "adresse")
        d.add(".\nAnimée par ").ent("{} {} {}".format(*personne(rng)[:3]), "nom")
        d.add(".\n")

    return d


# ---------------------------------------------------------------------------
# CORPUS TEMOIN — zero entite, uniquement des leurres LEGITIMES
#
# v2 : retrait de « contact@example.fr » et des noms d'etablissement, dont
# le masquage est en realite correct. Ne restent que des elements dont le
# masquage serait indefendable.
# ---------------------------------------------------------------------------


def doc_temoin(rng):
    d = Doc()
    variante = rng.randint(0, 3)

    if variante == 0:  # eponymes medicaux et sigles metier
        d.add("Le patient présente une ").add(rng.choice(EPONYMES_MEDICAUX))
        d.add(" ainsi qu'un début de ").add(rng.choice(EPONYMES_MEDICAUX))
        d.add(".\nÉvaluation par l'").add(rng.choice(SIGLES_METIER))
        d.add(" et la grille ").add(rng.choice(SIGLES_METIER))
        d.add(".\nScore ").add(rng.choice(SIGLES_METIER)).add(" inchangé.\n")

    elif variante == 1:  # nombres a cinq chiffres et numeros courts
        d.add("Le devis s'élève à 70000 euros hors taxes.\n")
        d.add("Le code postal de référence est 75015 pour l'antenne parisienne.\n")
        d.add("Référence interne 21000, dossier 39100.\n")
        d.add("Numéros d'urgence : 15, 112, 3949 et 39 77.\n")

    elif variante == 2:  # dates qui ne sont pas des naissances
        d.add("Facture du 05/07/2026, échéance au 05/08/2026, ")
        d.add("livraison le 12/07/2026.\n")
        d.add("Aucune de ces dates n'est une date de naissance.\n")
        d.add("Prochaine ").add(rng.choice(SIGLES_METIER))
        d.add(" le 03/09/2026.\n")

    else:  # identifiants d'entreprise et vocabulaire courant
        d.add("SIRET 12345678200010, TVA FR11123456782.\n")
        d.add("Le loyer et les charges sont dus au 5 de chaque mois.\n")
        d.add("Le boulanger et le berger du village ont été consultés.\n")
        d.add("Réunion ").add(rng.choice(SIGLES_METIER)).add(" à 14 h.\n")

    return d


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def write_corpus(path, docs):
    with open(path, "w", encoding="utf-8") as f:
        for doc in docs:
            f.write(json.dumps(doc, ensure_ascii=False) + "\n")


def stats(docs):
    counts, chars = {}, {}
    for doc in docs:
        for e in doc["entities"]:
            counts[e["type"]] = counts.get(e["type"], 0) + 1
            chars[e["type"]] = chars.get(e["type"], 0) + (e["end"] - e["start"])
    return counts, chars


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=400, help="documents par corpus")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out-dir", default=".")
    args = ap.parse_args()

    for name, factory in [("realiste", doc_realiste),
                          ("adversarial", doc_adversarial),
                          ("temoin", doc_temoin)]:
        # Un RNG par corpus : ajouter des documents a l'un ne decale pas les autres.
        rng = random.Random(f"{args.seed}:{name}")
        docs = [factory(rng).build(i) for i in range(args.n)]
        path = f"{args.out_dir}/corpus_flou_{name}.jsonl"
        write_corpus(path, docs)

        counts, chars = stats(docs)
        total = sum(counts.values())
        print(f"{path} : {len(docs)} documents, {total} entités")
        for t in sorted(counts):
            print(f"    {t:16s} {counts[t]:5d} entités  {chars[t]:6d} caractères")
        if not counts:
            print("    (aucune entité — corpus témoin, par construction)")


if __name__ == "__main__":
    main()
