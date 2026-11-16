#!/usr/bin/env python3
"""Tests de la mesure « écritures hors référentiel » (P2-215) :
`python3 -m unittest discover -s bench`. Noms de communes du référentiel
public versionné ou fabriqués, aucune donnée réelle."""

import random
import unittest

import ecritures_hors_referentiel as eh

NEUTRES = {"le", "la", "les", "l", "sous", "vers", "places", "et", "en"}
COMMUNES = [
    ("1", "07", "SAINT LAURENT LES BAINS LAVAL D AURELLE",
     "Saint-Laurent-les-Bains-Laval-d'Aurelle"),
    ("2", "58", "CHATEAU CHINON (VILLE)", "Château-Chinon (Ville)"),
    ("3", "80", "LES PLACES", "Les Places"),
    ("4", "09", "SOUS PARSAT", "Sous-Parsat"),
    ("5", "70", "VESOUL", "Vesoul"),
]


class Ecritures(unittest.TestCase):
    def test_formes_visees(self):
        self.assertEqual([eh.forme(c[2], c[3], NEUTRES) for c in COMMUNES],
                         ["A", "C", "D", None, None])

    def test_variantes(self):
        rng = random.Random(1)
        _, _, norm, lib = COMMUNES[0]
        self.assertEqual(eh.ecrit(rng, norm, lib, "reference"), norm)
        self.assertEqual(eh.ecrit(rng, norm, lib, "st"),
                         "ST LAURENT LES BAINS LAVAL D AURELLE")
        self.assertEqual(eh.ecrit(rng, norm, lib, "apostrophe_collee"),
                         "SAINT LAURENT LES BAINS LAVAL DAURELLE")
        colle = eh.ecrit(rng, norm, lib, "tiret_colle")
        self.assertEqual(colle.replace(" ", ""), norm.replace(" ", ""))
        self.assertEqual(len(colle.split()), len(norm.split()) - 1)
        fautive = eh.ecrit(rng, norm, lib, "lettre_fautive")
        self.assertEqual(len(fautive), len(norm))
        self.assertEqual(sum(a != b for a, b in zip(fautive, norm)), 1)
        self.assertEqual(len(eh.ecrit(rng, norm, lib, "lettre_omise")),
                         len(norm) - 1)

    def test_variante_sans_objet(self):
        rng = random.Random(1)
        self.assertIsNone(eh.ecrit(rng, "LES PLACES", "Les Places", "st"))
        self.assertIsNone(eh.ecrit(rng, "LES PLACES", "Les Places",
                                   "accents"))
        self.assertEqual(
            eh.ecrit(rng, "CHATEAU CHINON (VILLE)", "Château-Chinon (Ville)",
                     "accents"), "CHÂTEAU CHINON (VILLE)")

    def test_corpus_reproductible_et_positions(self):
        docs = eh.genere(42, COMMUNES, NEUTRES)
        self.assertEqual(docs, eh.genere(42, COMMUNES, NEUTRES))
        self.assertEqual({d["com"] for d in docs}, {"1", "2", "3"})
        for d in docs:
            self.assertEqual(d["text"], d["text"].upper())
            e = d["entities"][0]
            self.assertRegex(d["text"][e["start"]:e["end"]], r"^\d{5} \S")
            self.assertNotIn("\n", d["text"][e["start"]:e["end"]])
            self.assertEqual(d["parties"]["commune"][1], e["end"])


class Regles(unittest.TestCase):
    def setUp(self):
        self.table = eh.Table(["DHUYS ET MORIN EN BRIE",
                               "SAINT ANDRE SUR VIEUX JONC"], lettres_min=8)

    def _fin(self, regle, ligne):
        texte = f"A :\n12345 {ligne}\nFIN"
        e = eh.etendues(texte, regle, self.table)
        return texte[e[0][0]:e[0][1]] if e else None

    def test_exact(self):
        self.assertEqual(self._fin("exact", "DHUYS ET MORIN EN BRIE, B"),
                         "12345 DHUYS ET MORIN EN BRIE")
        self.assertIsNone(self._fin("exact", "ST ANDRE SUR VIEUX JONC"))
        self.assertIsNone(self._fin("exact", "DHUYS ET MORIN EN ATTENTE"))

    def test_normalise_abreviation_et_mots_colles(self):
        self.assertEqual(self._fin("normalise", "ST ANDRE SUR VIEUX JONC"),
                         "12345 ST ANDRE SUR VIEUX JONC")
        self.assertEqual(self._fin("normalise", "DHUYS ET MORINEN BRIE"),
                         "12345 DHUYS ET MORINEN BRIE")
        self.assertIsNone(self._fin("normalise", "DHUYS ET MORIN EN BRIX"))

    def test_distance1_une_lettre_pas_deux(self):
        for ligne in ("DHUYS ET MORIN EN BRIX", "DHYS ET MORIN EN BRIE",
                      "DHUYSS ET MORIN EN BRIE"):
            self.assertEqual(self._fin("distance1", ligne), f"12345 {ligne}")
        self.assertIsNone(self._fin("distance1", "DHUXS ET MORIN EN BRIX"))

    def test_distance1_pas_pour_un_nom_court(self):
        table = eh.Table(["VESOUL"], lettres_min=8)
        texte = "A :\n70000 VESOUX\nFIN"
        self.assertEqual(eh.etendues(texte, "distance1", table), [])
        self.assertEqual(len(eh.etendues("A :\n70000 VESOUL\nFIN",
                                         "distance1", table)), 1)

    def test_rien_hors_capitales(self):
        self.assertEqual(eh.etendues("a :\n12345 DHUYS ET MORIN EN BRIE",
                                     "exact", self.table), [])

    def test_lignes_sans_adresse(self):
        doc = {"text": "TITRE\n12345 X\nFIN",
               "entities": [{"start": 6, "end": 13}]}
        self.assertEqual(list(eh.lignes_sans_adresse(doc)),
                         [(0, 5), (14, 17)])


if __name__ == "__main__":
    unittest.main()
