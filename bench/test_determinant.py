#!/usr/bin/env python3
"""Tests du corpus temoin « cinq chiffres + determinant » (P2-187) :
`python3 -m unittest discover -s bench`. Donnees synthetiques."""

import re
import unittest

import generate_corpus_determinant as gd


class CorpusTest(unittest.TestCase):
    def test_reproductible_a_graine_egale(self):
        self.assertEqual(gd.construit(400, 42), gd.construit(400, 42))
        self.assertNotEqual(gd.construit(400, 42), gd.construit(400, 43))

    def test_aucune_entite_annotee(self):
        docs = gd.construit(400, 42)
        self.assertEqual(len(docs), 400)
        self.assertTrue(all(d["entities"] == [] for d in docs))

    def test_chaque_phrase_a_un_nombre_de_cinq_chiffres_et_un_determinant(self):
        for d in gd.construit(400, 42):
            self.assertRegex(d["text"], r"(?<!\d)\d{5}(?!\d)", d["text"])
            self.assertRegex(d["text"], r"(?i)\b(le|la|les)\b|\bl'", d["text"])

    def test_axes_couverts(self):
        docs = gd.construit(400, 42)
        for axe, valeurs in {
            "famille": {"quantite", "reference"},
            "suffixe": {"le", "la", "les", "l"},
            "position": {"debut", "milieu"},
            "casse": {"capitales", "ordinaire"},
        }.items():
            self.assertEqual({d[axe] for d in docs}, valeurs)

    def test_capitales_sans_minuscule_ordinaire_avec(self):
        for d in gd.construit(400, 42):
            minuscules = re.findall(r"[a-zà-öø-ÿ]", d["text"])
            if d["casse"] == "capitales":
                self.assertEqual(minuscules, [], d["text"])
            else:
                self.assertNotEqual(minuscules, [], d["text"])


if __name__ == "__main__":
    unittest.main()
