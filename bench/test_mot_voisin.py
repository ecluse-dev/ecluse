"""Tests du corpus « mot voisin devant un identifiant dicté abîmé » et de son
scoreur (P2-292). Données synthétiques, aucune valeur réelle."""

import random
import re
import unittest

from generate_corpus_mot_voisin import (DISTANCES, LIBELLES, MOTS_VOISINS, RE_LIBELLE,
                                        RE_VOISIN, amorce, mots_neutres)
from score_mot_voisin import classe, etat


class Generateur(unittest.TestCase):
    def test_mots_neutres_longueur_exacte(self):
        rng = random.Random(42)
        for n in range(1, 120):
            self.assertEqual(len(mots_neutres(n, rng)), n)

    def test_mots_neutres_sans_nombre_ni_libelle_ni_voisin(self):
        rng = random.Random(7)
        for n in range(1, 120):
            s = mots_neutres(n, rng)
            self.assertIsNone(RE_VOISIN.search(s))
            self.assertIsNone(RE_LIBELLE.search(s))
            self.assertFalse({"un", "deux", "et", "o", "zero", "cent"} & set(s.split()))

    def test_distance_exacte_du_mot_voisin(self):
        texte = "attention saisie erronée hier un deux trois"
        debut = texte.index("un deux")
        for mot in MOTS_VOISINS:
            for d in DISTANCES:
                for lib in (None, LIBELLES[0]):
                    ins = amorce(texte, debut, mot, lib, d, random.Random(1))
                    nouveau = texte[:debut] + ins + texte[debut:]
                    nd = debut + len(ins)
                    self.assertEqual(nd - nouveau.rfind(mot, 0, nd), d, (mot, d, lib))

    def test_temoin_sans_mot_voisin(self):
        ins = amorce("x ", 2, None, None, 60, random.Random(1))
        self.assertEqual(len(ins), 60)
        self.assertIsNone(RE_VOISIN.search(ins))

    def test_reproductible(self):
        a = amorce("x ", 2, "code", "iban", 80, random.Random(5))
        self.assertEqual(a, amorce("x ", 2, "code", "iban", 80, random.Random(5)))

    def test_miroirs_des_expressions_du_moteur(self):
        self.assertTrue(RE_VOISIN.search("le code est"))
        self.assertIsNone(RE_VOISIN.search("épinards"))
        self.assertIsNone(RE_VOISIN.search("digicodes"))
        self.assertTrue(RE_LIBELLE.search("code iban fr"))


class Scoreur(unittest.TestCase):
    ENT = {"type": "nir", "start": 10, "end": 30}

    def test_masque_en_entier(self):
        pred = {"entities": [{"start": 10, "end": 20}, {"start": 20, "end": 30}],
                "signalements": 0}
        self.assertEqual(etat(self.ENT, pred), "masqué")

    def test_partiel_signale(self):
        pred = {"entities": [{"start": 10, "end": 20}], "signalements": 1}
        self.assertEqual(etat(self.ENT, pred), "signalé")

    def test_rien(self):
        self.assertEqual(etat(self.ENT, {"entities": [], "signalements": 0}), "rien")
        pred = {"entities": [{"start": 10, "end": 20}], "signalements": 0}
        self.assertEqual(etat(self.ENT, pred), "rien")

    def test_classes(self):
        self.assertEqual(classe({"bras": "temoin"}), "temoin")
        self.assertEqual(classe({"bras": "sans_lib", "lib_fenetre": False}), "sans_lib")
        self.assertEqual(classe({"bras": "sans_lib", "lib_fenetre": True}),
                         "sans_lib_origine")
        self.assertEqual(classe({"bras": "avec_lib", "lib_fenetre": True}), "avec_lib")


if __name__ == "__main__":
    unittest.main()
