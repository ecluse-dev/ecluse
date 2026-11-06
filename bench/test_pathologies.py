#!/usr/bin/env python3
"""Tests du corpus de pathologies (P2-112) :
`python3 -m unittest discover -s bench` (depuis la racine)."""

import unittest

import generate_corpus_pathologies as g


class CorpusPathologiesTest(unittest.TestCase):
    def test_offsets_exacts(self):
        for d in g.construit("indices", 200, 42):
            self.assertTrue(d["pathologies"])
            for p in d["pathologies"]:
                self.assertEqual(d["text"][p["start"]:p["end"]], p["mention"])

    def test_mentions_tirees_de_la_table(self):
        connues = {m for _, _, m in g.ENTREES}
        for d in g.construit("indices", 200, 42):
            for p in d["pathologies"]:
                self.assertIn(p["mention"], connues)
                self.assertTrue(p["categorie"] and p["systeme"])

    def test_temoin_sans_annotation(self):
        for d in g.construit("temoin", 200, 42):
            self.assertEqual(d["pathologies"], [])

    def test_reproductible_et_prefixe_stable(self):
        self.assertEqual(g.construit("indices", 50, 42),
                         g.construit("indices", 50, 42))
        self.assertEqual(g.construit("indices", 100, 42)[:50],
                         g.construit("indices", 50, 42))
        self.assertNotEqual(g.construit("indices", 50, 42),
                            g.construit("indices", 50, 7))


if __name__ == "__main__":
    unittest.main()
