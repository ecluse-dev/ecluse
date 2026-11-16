#!/usr/bin/env python3
"""Tests du corpus témoin « cinq chiffres + mot neutre + CEDEX » (P2-200) et
de l'option `--cedex sans` du balayage : `python3 -m unittest discover -s
bench`."""

import os
import re
import unittest

import generate_corpus_cedex as gc
import generate_corpus_neutre_cedex as gn

ICI = os.path.dirname(os.path.abspath(__file__))
COMMUNES = os.path.join(ICI, "..", "packages", "ecluse_reference", "assets",
                        "geo_communes.csv.gz")


class NeutreCedexTest(unittest.TestCase):
    def test_reproductible_a_graine_egale(self):
        self.assertEqual(gn.construit(120, 42), gn.construit(120, 42))
        self.assertNotEqual(gn.construit(120, 42), gn.construit(120, 43))

    def test_aucune_entite_et_forme_attendue(self):
        for d in gn.construit(240, 42):
            self.assertEqual(d["entities"], [])
            self.assertRegex(d["text"], r"(?<!\d)\d{5} .*CEDEX \d\.",
                             "pas de forme « cinq chiffres ... CEDEX n »")
            if d["casse"] == "capitales":
                self.assertEqual(d["text"], d["text"].upper())
            else:
                self.assertTrue(re.search(r"[a-zé]", d["text"]))

    def test_tous_les_axes_sont_couverts(self):
        docs = gn.construit(240, 42)
        for axe in ("famille", "suffixe", "position", "casse"):
            self.assertGreater(len({d[axe] for d in docs}), 1, axe)
        self.assertEqual({d["suffixe"] for d in docs},
                         {"mot", "parenthese", "tiret"})
        self.assertTrue(any("(TTC)" in d["text"].upper() for d in docs))

    def test_ids_contigus(self):
        self.assertEqual([d["id"] for d in gn.construit(50, 42)],
                         list(range(50)))


class BalayageSansCedexTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.par_mots = gc.lit_communes(COMMUNES)

    def test_defaut_inchange(self):
        # Le corpus « CEDEX n » existant ne change pas d'un octet.
        a = gc.construit(self.par_mots, 40, 42, True)
        b = gc.construit(self.par_mots, 40, 42, True, "CEDEX n")
        self.assertEqual(a, b)
        self.assertTrue(all(d["cedex"] == "CEDEX n" for d in a))
        self.assertTrue(all("CEDEX" in d["text"] for d in a))

    def test_sans_cedex_meme_communes_sans_mot_cedex(self):
        avec = gc.construit(self.par_mots, 40, 42, True)
        sans = gc.construit(self.par_mots, 40, 42, True, "sans")
        self.assertEqual(len(avec), len(sans))
        self.assertEqual([(d["com"], d["ecriture"]) for d in avec],
                         [(d["com"], d["ecriture"]) for d in sans])
        for d in sans:
            self.assertEqual(d["cedex"], "sans")
            self.assertNotIn("CEDEX", d["text"].upper())
            self.assertIsNone(d["parties"]["cedex"])
            e = d["entities"][0]
            adresse = d["text"][e["start"]:e["end"]]
            self.assertEqual(adresse.split("\n")[0], adresse)
            self.assertTrue(adresse.endswith(
                d["text"][slice(*d["parties"]["commune"])]))


if __name__ == "__main__":
    unittest.main()
