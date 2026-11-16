#!/usr/bin/env python3
"""Tests du corpus de courriers en capitales et de son scoreur (P2-210) :
`python3 -m unittest discover -s bench`. Donnees synthetiques."""

import os
import re
import unittest

import generate_corpus_courriers as gcc
import score_courriers as sc

ICI = os.path.dirname(os.path.abspath(__file__))
COMMUNES = os.path.join(ICI, "..", "packages", "ecluse_reference", "assets",
                        "geo_communes.csv.gz")


class CorpusCourriers(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.communes = gcc.charge(COMMUNES)
        cls.docs = gcc.construit(200, 42, cls.communes)

    def test_reproductible_a_graine_egale(self):
        self.assertEqual(self.docs, gcc.construit(200, 42, self.communes))
        self.assertNotEqual(self.docs, gcc.construit(200, 43, self.communes))

    def test_tout_en_capitales(self):
        for d in self.docs:
            self.assertEqual(d["text"], d["text"].upper())

    def test_au_moins_une_adresse_et_positions_exactes(self):
        for d in self.docs:
            self.assertGreaterEqual(len(d["entities"]), 1)
            for e in d["entities"]:
                self.assertRegex(d["text"][e["start"]:e["end"]],
                                 r"^\d{5} [A-Z0-9 ]+ CEDEX \d$")
            for lg in d["lignes"]:
                self.assertEqual(d["text"][lg["fin"]], "\n")

    def test_les_six_familles_sont_tirees(self):
        vues = {lg["famille"] for d in self.docs for lg in d["lignes"]}
        self.assertEqual(vues, {f for f, _ in gcc.FAMILLES})

    def test_la_famille_montant_adresse_porte_les_deux_formes(self):
        lignes = [d["text"][lg["debut"]:lg["fin"]] for d in self.docs
                  for lg in d["lignes"] if lg["famille"] == "montant_adresse"]
        self.assertTrue(lignes)
        for t in lignes:
            self.assertRegex(t, r"\d{5} (?:EUROS?) (?:HT|TTC),? RETOUR A "
                                r"\d{5} .* CEDEX \d$")
        self.assertTrue(any("," in t for t in lignes))
        self.assertTrue(any("," not in t for t in lignes))

    def test_aucun_nom_de_personne_ni_valeur_hors_motif(self):
        for d in self.docs:
            for lg in d["lignes"]:
                if lg["famille"] in ("reference", "texte"):
                    t = d["text"][lg["debut"]:lg["fin"]]
                    self.assertFalse(re.search(r"\bM\.|MME|MADAME", t))


class Scoreur(unittest.TestCase):
    def setUp(self):
        self.doc = {
            "id": 0, "text": "FACTURE\nTOTAL : 70000 EUROS HT\n"
                             "RETOUR A 25000 BESANCON CEDEX 2\nFIN",
            "entities": [{"type": "adresse", "start": 40, "end": 62}],
            "lignes": [
                {"famille": "montant", "debut": 8, "fin": 30},
                {"famille": "adresse", "debut": 31, "fin": 62}]}

    def test_rien_en_trop_adresse_couverte(self):
        pred = {"entities": [{"type": "adresse", "start": 40, "end": 62}]}
        adr, clair, fam, trop, types, mots = sc.juge(self.doc, pred)
        self.assertEqual((adr, clair, trop), (1, 0, False))
        self.assertEqual(fam["montant"], [1, 0])

    def test_masquage_en_trop_compte_par_ligne_et_par_mot(self):
        pred = {"entities": [{"type": "adresse", "start": 8, "end": 30},
                             {"type": "adresse", "start": 40, "end": 62}]}
        _, _, fam, trop, types, mots = sc.juge(self.doc, pred)
        self.assertTrue(trop)
        self.assertEqual(fam["montant"], [1, 1])
        self.assertEqual(types["adresse"], 1)
        self.assertEqual(mots["EUROS"], [1, 1])

    def test_adresse_en_partie_en_clair_est_une_fuite(self):
        pred = {"entities": [{"type": "adresse", "start": 40, "end": 50}]}
        _, clair, _, _, _, _ = sc.juge(self.doc, pred)
        self.assertEqual(clair, 1)

    def test_le_libelle_d_une_adresse_masque_compte_en_trop(self):
        pred = {"entities": [{"type": "adresse", "start": 31, "end": 62}]}
        _, clair, fam, trop, _, _ = sc.juge(self.doc, pred)
        self.assertEqual(clair, 0)
        self.assertEqual(fam["adresse"], [1, 1])


if __name__ == "__main__":
    unittest.main()
