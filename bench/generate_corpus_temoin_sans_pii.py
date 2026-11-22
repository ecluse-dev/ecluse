#!/usr/bin/env python3
"""Corpus TEMOIN de documents realistes du soin et du social **sans aucune
donnee personnelle** (P2-246, mesure).

Pourquoi. Le corpus v3 n'annote que des identifiants structurels : la ligne
« masques a tort » du comparatif (P2-224) y compte comme fautes des noms, des
telephones et des numeros de dossier que le corpus n'annote pas. Ce temoin
n'a, lui, **aucune** donnee personnelle, ni annotee ni cachee : tout ce qu'un
outil y masque est un masquage en trop (de la lisibilite perdue, pas une
fuite).

Contenu : consignes de service, comptes rendus de reunion sans nom, protocoles,
plannings de salles, notes logistiques et courriers types, en casse ordinaire,
avec ce qui fait dechoir les detecteurs :

- titres en majuscules initiales (« Compte Rendu De La Reunion ») ;
- sigles (EHPAD, SAMSAH, ARS, CPOM...) et fonctions sans nom propre ;
- numeros non personnels : salles, pages, articles de loi, codes de protocole,
  nombres de lits, horaires, montants ;
- marques et logiciels (Doliprane, Teams, Excel, Renault...) ;
- villes (pour les trajets et les sites : jamais une adresse ni un code postal) ;
- verbes a l'infinitif, a l'imperatif et a la 3e personne en tete de phrase,
  y compris des formes proches de prenoms ecrites comme des verbes.

Regles de fabrication : aucun prenom ni nom de famille, aucun numero de
telephone, aucun e-mail, aucun IBAN, aucun numero de securite sociale ni de
dossier, aucune adresse postale. Les numeros ci-dessus sont de formats courts
ou prefixes de lettres, jamais des identifiants valides. Aucune entite n'est
annotee (`"entities": []`). Chaque document porte sa `famille` pour que la
mesure se decompose. Graine fixe : meme sortie a chaque lancement.

Usage :
    python3 generate_corpus_temoin_sans_pii.py --n 480 --seed 42 \\
        --out comparatif/corpus_temoin.jsonl
"""

import argparse
import json
import random

VILLES = ["Lyon", "Nantes", "Lille", "Rennes", "Dijon", "Tours", "Rouen",
          "Metz", "Brest", "Angers", "Limoges", "Poitiers", "Amiens"]
SERVICES = ["le service de soins de suite", "l'unité de vie protégée",
            "le pôle gériatrie", "le foyer d'accueil médicalisé",
            "l'accueil de jour", "le service d'aide à domicile",
            "la résidence autonomie", "le SAMSAH", "l'EHPAD",
            "le service de pédiatrie", "la cuisine centrale"]
FONCTIONS = ["la cadre de santé", "le directeur adjoint", "l'infirmier coordinateur",
             "la psychologue du service", "le médecin coordonnateur",
             "l'assistante sociale", "la responsable qualité",
             "l'éducateur référent", "le référent hygiène",
             "l'ergothérapeute", "la diététicienne", "le gestionnaire"]
SIGLES = ["ARS", "HAS", "CPOM", "CASF", "CSE", "DUERP", "PAI", "GIR", "APA",
          "MDPH", "CHU", "EHPAD", "SAMSAH", "SSIAD", "CNSA", "RGPD", "DASRI"]
MARQUES = ["Doliprane", "Teams", "Excel", "Renault Master", "Ikea", "Leclerc",
           "Philips", "Outlook", "Spontex", "Bic", "Nespresso", "Zoom"]
MOIS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet",
        "septembre", "octobre", "novembre", "décembre"]
JOURS = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
THEMES = ["la gestion des stocks de linge", "la sécurité incendie",
          "le circuit du médicament", "la prévention des chutes",
          "le tri des déchets", "la formation aux gestes d'urgence",
          "le bilan annuel de la qualité", "le plan canicule",
          "la désinfection des chambres", "la révision du projet d'établissement",
          "l'astreinte de week-end", "la livraison des repas"]

# Debuts de phrase : verbes (infinitif, imperatif, 3e personne), dont des
# formes que des detecteurs de prenoms confondent avec des noms propres.
VERBES_TETE = ["Prévoir", "Vérifier", "Ouvrir", "Fermer", "Rappeler",
               "Noter", "Signaler", "Contrôler", "Valider", "Transmettre",
               "Rappelle", "Précise", "Confirme", "Demande", "Vérifie",
               "Arrive", "Commence", "Termine", "Passe", "Dépose",
               "Informer", "Remplacer", "Archiver", "Conserver"]


def tire(rng, liste):
    return rng.choice(liste)


def numero(rng):
    """Numeros non personnels : salle, page, article, protocole, lits."""
    k = rng.randrange(7)
    if k == 0:
        return f"salle {rng.randrange(101, 480)}"
    if k == 1:
        p = rng.randrange(1, 30)
        return f"page {p}/{p + rng.randrange(1, 20)}"
    if k == 2:
        return f"article L. {rng.randrange(111, 400)}-{rng.randrange(1, 12)} du CASF"
    if k == 3:
        return f"protocole PRO-{rng.randrange(2019, 2027)}-{rng.randrange(1, 40):02d}"
    if k == 4:
        return f"{rng.randrange(12, 90)} lits"
    if k == 5:
        return f"chambre {rng.randrange(1, 60)}"
    return f"fiche FT-{rng.randrange(1, 99):02d}"


def horaire(rng):
    return f"{rng.randrange(7, 19)} h {rng.choice(['00', '15', '30', '45'])}"


def titre_casse(rng, base):
    """Titre en majuscules initiales ou en capitales, selon le tirage."""
    k = rng.randrange(3)
    if k == 0:
        return " ".join(m.capitalize() for m in base.split())
    if k == 1:
        return base.upper()
    return base[0].upper() + base[1:]


def consigne_service(rng):
    t = titre_casse(rng, f"consignes pour {tire(rng, THEMES)}")
    return [t + ".",
            f"{tire(rng, VERBES_TETE)} {tire(rng, THEMES)} avant {horaire(rng)}.",
            f"Voir {numero(rng)} et le document {tire(rng, SIGLES)}.",
            f"{tire(rng, VERBES_TETE)} les consignes dans {tire(rng, SERVICES)} le {tire(rng, JOURS)}.",
            f"Merci de prévenir {tire(rng, FONCTIONS)} en cas de retard.",
            f"Le matériel livré par {tire(rng, MARQUES)} est rangé {numero(rng)}."]


def compte_rendu(rng):
    t = titre_casse(rng, f"compte rendu de la réunion du {rng.randrange(1, 28)} {tire(rng, MOIS)}")
    return [t + ".",
            f"Présents : {tire(rng, FONCTIONS)}, {tire(rng, FONCTIONS)} et {tire(rng, FONCTIONS)}.",
            f"Ordre du jour : {tire(rng, THEMES)}, puis {tire(rng, THEMES)}.",
            f"{tire(rng, FONCTIONS).capitalize()} rappelle que {tire(rng, THEMES)} reste prioritaire.",
            f"{tire(rng, VERBES_TETE)} un point d'étape avec {tire(rng, SIGLES)} à {tire(rng, VILLES)}.",
            f"Décision : {tire(rng, VERBES_TETE).lower()} la mise à jour avant le {rng.randrange(1, 28)} {tire(rng, MOIS)}.",
            f"Prochaine réunion le {tire(rng, JOURS)} à {horaire(rng)}, {numero(rng)}."]


def protocole(rng):
    t = titre_casse(rng, f"protocole de {tire(rng, THEMES)}")
    return [t + f" ({numero(rng)}).",
            f"Objet : cadrer {tire(rng, THEMES)} dans {tire(rng, SERVICES)}.",
            f"Étape 1 : {tire(rng, VERBES_TETE).lower()} le matériel {tire(rng, MARQUES)}.",
            f"Étape 2 : {tire(rng, VERBES_TETE).lower()} {numero(rng)} puis noter l'heure.",
            f"Références : {tire(rng, SIGLES)}, {tire(rng, SIGLES)}, {numero(rng)}.",
            f"Révision prévue en {tire(rng, MOIS)} par {tire(rng, FONCTIONS)}."]


def planning_salles(rng):
    lignes = [titre_casse(rng, "planning des salles de la semaine") + "."]
    for j in rng.sample(JOURS, 4):
        lignes.append(f"{j.capitalize()} : {numero(rng)} réservée de {horaire(rng)} à "
                      f"{horaire(rng)} pour {tire(rng, THEMES)}.")
    lignes.append(f"Clés à retirer auprès de {tire(rng, FONCTIONS)}.")
    return lignes


def note_logistique(rng):
    return [titre_casse(rng, f"note logistique {tire(rng, SERVICES)}") + ".",
            f"Livraison {tire(rng, MARQUES)} prévue le {tire(rng, JOURS)} entre "
            f"{horaire(rng)} et {horaire(rng)}.",
            f"Le véhicule part de {tire(rng, VILLES)} et passe par {tire(rng, VILLES)}.",
            f"{tire(rng, VERBES_TETE)} {numero(rng)} avant l'arrivée du camion.",
            f"Budget prévu : {rng.randrange(120, 9800)} euros, imputés sur {tire(rng, SIGLES)}.",
            f"Contact : {tire(rng, FONCTIONS)}, poste interne {rng.randrange(100, 999)}."]


def courrier_type(rng):
    return [f"Objet : {tire(rng, THEMES)}.",
            "Madame, Monsieur,",
            f"Nous vous informons que {tire(rng, SERVICES)} modifie ses horaires à compter du "
            f"{rng.randrange(1, 28)} {tire(rng, MOIS)}.",
            f"{tire(rng, VERBES_TETE)} la procédure décrite {numero(rng)} avant cette date.",
            f"Pour toute question, la direction de {tire(rng, SERVICES)} reste à votre disposition.",
            "Veuillez agréer, Madame, Monsieur, nos salutations distinguées.",
            f"La direction, {tire(rng, SERVICES)}, {tire(rng, VILLES)}."]


FAMILLES = {
    "consigne_service": consigne_service,
    "compte_rendu": compte_rendu,
    "protocole": protocole,
    "planning_salles": planning_salles,
    "note_logistique": note_logistique,
    "courrier_type": courrier_type,
}


def genere(n, seed):
    rng = random.Random(seed)
    noms = sorted(FAMILLES)
    docs = []
    for i in range(n):
        famille = noms[i % len(noms)]  # parts egales, ordre fixe
        texte = "\n".join(FAMILLES[famille](rng))
        docs.append({"id": i, "text": texte, "entities": [],
                     "famille": famille, "source": "temoin"})
    return docs


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--n", type=int, default=480)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    docs = genere(a.n, a.seed)
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{len(docs)} documents écrits dans {a.out} (aucune entité annotée)")


if __name__ == "__main__":
    main()
