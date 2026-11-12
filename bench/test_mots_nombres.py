#!/usr/bin/env python3
"""Tests du corpus temoin « mots-nombres » (P2-160) :
`python3 -m unittest discover -s bench`. Donnees synthetiques."""

import unittest

import generate_corpus_mots_nombres as mn


class SuiteTest(unittest.TestCase):
    def test_plus_longue_suite(self):
        f = mn.plus_longue_suite
        self.assertEqual(f("deux cent cinquante mille euros"), 4)
        self.assertEqual(f("deux mille trois cent quarante cinq"), 6)
        self.assertEqual(f("vingt et un ans"), 3)
        self.assertEqual(f("quatre-vingt-treize"), 3)
        self.assertEqual(f("un seul mot, et un autre"), 1)
        self.assertEqual(f("rien ici"), 0)
        # espaces, virgules et tirets ne coupent pas la suite (spec § 4.1) ;
        # un mot ordinaire la coupe
        self.assertEqual(f("un deux trois, quatre cinq six sept"), 7)
        self.assertEqual(f("un deux trois fois quatre cinq six sept"), 4)

    def test_grand_nombre(self):
        self.assertEqual(mn.grand_nombre(250_000), "deux cent cinquante mille")
        self.assertEqual(mn.grand_nombre(1000), "mille")
        self.assertEqual(mn.grand_nombre(2026), "deux mille vingt-six")
        self.assertEqual(mn.grand_nombre(999_999),
                         "neuf cent quatre-vingt-dix-neuf mille neuf cent "
                         "quatre-vingt-dix-neuf")


class CorpusTest(unittest.TestCase):
    docs = mn.construit(300, 42)

    def test_taille_et_aucune_entite(self):
        self.assertEqual(len(self.docs), 300)
        self.assertEqual([d["id"] for d in self.docs], list(range(300)))
        self.assertTrue(all(d["entities"] == [] for d in self.docs))

    def test_aucun_chiffre(self):
        for d in self.docs:
            self.assertNotRegex(d["text"], r"\d", d["text"])

    def test_moitie_a_au_moins_six_mots_nombres(self):
        longues = sum(mn.plus_longue_suite(d["text"]) >= mn.SEUIL_K
                      for d in self.docs)
        self.assertEqual(longues, 150)

    def test_phrases_distinctes_en_grand_nombre(self):
        self.assertGreater(len({d["text"] for d in self.docs}), 200)

    def test_reproductible_par_graine(self):
        self.assertEqual(mn.construit(300, 42), self.docs)
        self.assertNotEqual(mn.construit(300, 43), self.docs)

    def test_quatre_familles_presentes(self):
        textes = " ".join(d["text"] for d in self.docs)
        for mot in ("euros", "participants", "Comptez", "inventaire"):
            self.assertIn(mot, textes)


if __name__ == "__main__":
    unittest.main()
