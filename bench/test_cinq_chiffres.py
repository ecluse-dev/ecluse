#!/usr/bin/env python3
"""Tests du corpus temoin « nombres a cinq chiffres » (P2-167) :
`python3 -m unittest discover -s bench`. Donnees synthetiques."""

import re
import unittest

import generate_corpus_cinq_chiffres as cc


class CorpusTest(unittest.TestCase):
    def test_reproductible_a_graine_egale(self):
        self.assertEqual(cc.construit(400, 42), cc.construit(400, 42))
        self.assertNotEqual(cc.construit(400, 42), cc.construit(400, 43))

    def test_aucune_entite_annotee(self):
        docs = cc.construit(400, 42)
        self.assertEqual(len(docs), 400)
        self.assertTrue(all(d["entities"] == [] for d in docs))

    def test_chaque_phrase_a_un_nombre_de_cinq_chiffres(self):
        for d in cc.construit(400, 42):
            self.assertRegex(d["text"], r"(?<!\d)\d{5}(?!\d)", d["text"])

    def test_axes_couverts(self):
        docs = cc.construit(400, 42)
        for axe, valeurs in {
            "famille": {"quantite", "montant", "reference"},
            "suffixe": {"minuscule", "majuscule", "rien"},
            "position": {"debut", "milieu"},
            "casse": {"ordinaire", "phrase"},
        }.items():
            self.assertEqual({d[axe] for d in docs}, valeurs)

    def test_casse_de_phrase_sans_majuscule_hors_debut(self):
        # En casse « phrase », seule l'initiale du texte est en majuscule ; en
        # casse ordinaire il y a au moins une autre majuscule.
        for d in cc.construit(400, 42):
            hors_initiale = re.findall(r"[A-ZÀ-ÖØ-Þ]", d["text"][1:])
            if d["casse"] == "phrase":
                self.assertEqual(hors_initiale, [], d["text"])
            else:
                self.assertNotEqual(hors_initiale, [], d["text"])

    def test_mot_a_majuscule_implique_casse_ordinaire(self):
        for d in cc.construit(400, 42):
            if d["suffixe"] == "majuscule":
                self.assertEqual(d["casse"], "ordinaire", d["text"])


if __name__ == "__main__":
    unittest.main()
