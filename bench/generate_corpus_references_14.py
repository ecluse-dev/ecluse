#!/usr/bin/env python3
"""Corpus de P2-311 (mesure) : textes logistiques et administratifs **sans aucune
donnée personnelle**, qui portent des références de quatorze chiffres (numéro de
suivi, commande, lot, facture, horodatage) et des formes de TVA (« FR » + clé +
neuf chiffres). Sert à chiffrer ce que coûterait de **masquer** un SIRET de clé
juste sans le mot « siret » et une TVA à clé fausse sans libellé (P2-307 les
signale seulement).

Synthétique : chaque nombre est tiré au hasard (graine fixe), jamais copié d'une
source réelle. Aucune entité n'est annotée : tout masquage d'un de ces textes est
un masquage en trop. Chaque document note `forme` et, pour chaque référence,
ses positions et si sa clé de Luhn est juste (`luhn`), pour que l'analyse puisse
simuler le masquage sans toucher au code du produit.

Formes (une référence par document) :

- `suivi_colis`, `commande`, `lot`, `facture` : quatorze chiffres collés tirés
  uniformément ;
- `horodatage` : AAAAMMJJhhmmss, tiré dans une plage de dates plausible ;
- `groupe_3335` : quatorze chiffres écrits « 3 3 3 5 », la forme d'un SIRET ;
- `groupe_4442` : quatorze chiffres écrits « 4 4 4 2 », forme que le détecteur
  de SIRET ne lit pas ;
- `tva_cle_fausse` : « FR » + clé de deux chiffres fausse + neuf chiffres, sans
  libellé ;
- `tva_cle_lettre` : « FR » + clé à lettre + neuf chiffres, sans libellé ;
- `sans_reference` : texte sans nombre de quatorze chiffres (témoin).

Usage : python3 generate_corpus_references_14.py --n 300 --seed 42 --out c.jsonl
"""
import argparse
import json
import random


def luhn_ok(s):
    total, dbl = 0, False
    for ch in reversed(s):
        v = int(ch)
        if dbl:
            v = v * 2 - 9 if v * 2 > 9 else v * 2
        total += v
        dbl = not dbl
    return total % 10 == 0


def cle_tva(siren):
    return (12 + 3 * (int(siren) % 97)) % 97


def chiffres(rng, n):
    return "".join(str(rng.randrange(10)) for _ in range(n))


GABARITS = {
    "suivi_colis": ["Colis n° {r} expédié par le transporteur, livraison prévue jeudi.",
                    "Suivi {r} : colis pris en charge à l'entrepôt de départ.",
                    "Le colis {r} est en cours d'acheminement vers la plateforme."],
    "commande": ["Référence de commande : {r}, validée par le service achats.",
                 "Commande {r} reçue, préparation en cours.",
                 "Bon de commande {r} à rapprocher de la facture."],
    "lot": ["Lot {r} contrôlé à la réception, aucune anomalie signalée.",
            "Numéro de lot {r} : palette 4, rayon C.",
            "Rappel du lot {r} sur la chaîne de conditionnement."],
    "facture": ["Facture n° {r} à régler sous trente jours.",
                "Avoir {r} émis suite au retour de marchandise.",
                "Rapprochement de la facture {r} avec le bon de livraison."],
    "horodatage": ["Export généré {r} par la tâche de nuit.",
                   "Fichier déposé {r}, traitement terminé sans erreur.",
                   "Sauvegarde {r} archivée sur le serveur interne."],
    "groupe_3335": ["Dossier transport {r} clôturé par l'exploitation.",
                    "Référence interne {r} saisie dans l'outil de suivi.",
                    "Bordereau {r} rattaché au chargement du matin."],
    "groupe_4442": ["Dossier transport {r} clôturé par l'exploitation.",
                    "Référence interne {r} saisie dans l'outil de suivi.",
                    "Bordereau {r} rattaché au chargement du matin."],
    "tva_cle_fausse": ["Code article {r} à reporter dans la nomenclature.",
                       "Référence fournisseur {r} saisie sur la fiche produit.",
                       "Merci de recopier {r} dans la case prévue."],
    "tva_cle_lettre": ["Code article {r} à reporter dans la nomenclature.",
                       "Référence fournisseur {r} saisie sur la fiche produit.",
                       "Merci de recopier {r} dans la case prévue."],
    "sans_reference": ["Réunion de planning lundi à 14 h, salle 3, ordre du jour inchangé.",
                       "Le camion de 7 h est parti avec 12 palettes, retour prévu à 16 h.",
                       "Inventaire du rayon C terminé : 240 références contrôlées."],
}
FORMES = list(GABARITS)


def fabrique(forme, rng):
    """(texte de la référence, chiffres purs de quatorze, ou None)."""
    if forme in ("suivi_colis", "commande", "lot", "facture"):
        d = chiffres(rng, 14)
        return d, d
    if forme == "horodatage":
        d = (f"{rng.randrange(2019, 2027)}{rng.randrange(1, 13):02d}"
             f"{rng.randrange(1, 29):02d}{rng.randrange(24):02d}"
             f"{rng.randrange(60):02d}{rng.randrange(60):02d}")
        return d, d
    if forme == "groupe_3335":
        d = chiffres(rng, 14)
        return f"{d[:3]} {d[3:6]} {d[6:9]} {d[9:]}", d
    if forme == "groupe_4442":
        d = chiffres(rng, 14)
        return f"{d[:4]} {d[4:8]} {d[8:12]} {d[12:]}", d
    if forme in ("tva_cle_fausse", "tva_cle_lettre"):
        siren = chiffres(rng, 9)
        if forme == "tva_cle_fausse":
            juste = cle_tva(siren)
            cle = rng.choice([f"{c:02d}" for c in range(100) if c != juste])
        else:
            cle = rng.choice("ABCDEFGHJKLMNPQRSTUVWXYZ") + str(rng.randrange(10))
        return f"FR{cle}{siren}", None
    return None, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=300, help="documents par forme")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    rng = random.Random(a.seed)
    docs = []
    for forme in FORMES:
        for _ in range(a.n):
            ecrit, d = fabrique(forme, rng)
            gabarit = rng.choice(GABARITS[forme])
            texte = gabarit.format(r=ecrit) if ecrit else gabarit
            doc = {"id": len(docs), "text": texte, "forme": forme, "entities": []}
            if ecrit:
                debut = texte.index(ecrit)
                doc["ref"] = {"start": debut, "end": debut + len(ecrit)}
                if d:
                    doc["ref"]["luhn"] = luhn_ok(d)
                else:
                    doc["ref"]["tva"] = True
            docs.append(doc)
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{len(docs)} documents écrits dans {a.out} (aucune entité annotée)")


if __name__ == "__main__":
    main()
