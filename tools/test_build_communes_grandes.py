"""Tests de `build_communes_grandes.py` (P2-220, seuil releve a 100 000 par P2-239).

    python3 -m unittest tools/test_build_communes_grandes.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import build_communes_grandes as b  # noqa: E402

LIGNES = [
    "1;25;27;118489;BESANCON;Besançon\n",
    "2;70;27;15078;VESOUL;Vesoul\n",
    "3;70;27;9999;QUINGEY;Quingey\n",
    "4;75;11;;PARIS;Paris\n",
    "5;93;11;90000;SAINT DENIS;Saint-Denis\n",
    "trop;court\n",
]


class Selection(unittest.TestCase):
    def test_seuil_et_population_absente(self):
        self.assertEqual(b.selectionne(LIGNES), {"BESANCON", "PARIS"})

    def test_bornes_du_seuil(self):
        self.assertEqual(b.SEUIL, 100000)
        lignes = ["1;1;1;100000;PILE;Pile\n", "2;1;1;99999;JUSTE;Juste\n"]
        self.assertEqual(b.selectionne(lignes), {"PILE"})

    def test_cle_sans_ponctuation(self):
        self.assertEqual(b.cle("SAINT-DENIS (VILLE)"), "SAINT DENIS VILLE")


class Parite(unittest.TestCase):
    def test_fichier_dart_a_jour(self):
        with open(b.SORTIE, encoding="utf-8") as f:
            self.assertEqual(f.read(), b.construit(),
                             "relancer tools/build_communes_grandes.py")


if __name__ == "__main__":
    unittest.main()
