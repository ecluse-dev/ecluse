"""Tests des outils de P2-295 (type + mot générique). Synthétique."""

import json
import os
import tempfile
import unittest

from analyse_type_mot_generique import couvert, garde_referentiel, norme
from generate_sonde_type_generique import construit
from restreint_sans_personne import motif


class Outils(unittest.TestCase):
    def test_sonde(self):
        d = construit()
        self.assertEqual(len(d), 32)
        self.assertEqual(sum(1 for x in d if x["genre"] == "generique"), 18)
        self.assertTrue(all(x["nom"] in x["text"] for x in d))

    def test_norme(self):
        self.assertEqual(norme("Saint-Étienne"), "SAINT ETIENNE")
        self.assertEqual(norme("D'accueil"), "D ACCUEIL")

    def test_restreint_garde_les_motscles_suivis_d_un_mot(self):
        m = motif()
        self.assertTrue(m.search("la Résidence Autonomie est ouverte"))
        self.assertTrue(m.search("le CHU à Lille"))
        self.assertIsNone(m.search("sandwich au jambon"))
        self.assertIsNone(m.search("la résidence autonomie"))

    def test_couvert(self):
        e = {"start": 5, "end": 15}
        self.assertTrue(couvert(e, [(0, 10), (10, 20)]))
        self.assertFalse(couvert(e, [(0, 10), (12, 20)]))

    def test_referentiel(self):
        self.assertFalse(garde_referentiel("Résidence Autonomie"))
        self.assertTrue(garde_referentiel("EHPAD Les Tilleuls"))
        self.assertTrue(garde_referentiel("Clinique Pasteur"))


if __name__ == "__main__":
    unittest.main()
