#!/usr/bin/env python3
"""Tests du temoin « commune suivie de mots ordinaires » et de son scoreur
(P2-181) : `python3 -m unittest discover -s bench`. Noms de lieux publics,
reste synthetique."""

import re
import unittest

import generate_corpus_commune_suivie as cs
import score_commune_suivie as sc


class CorpusTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.docs = cs.construit(480, 42)

    def test_reproductible_a_graine_egale(self):
        self.assertEqual(self.docs, cs.construit(480, 42))
        self.assertNotEqual(self.docs, cs.construit(480, 43))

    def test_axes_couverts_et_equilibres(self):
        self.assertEqual(len(self.docs), 480)
        for axe, valeurs in {
            "famille": {"capitales", "majuscule", "liaison"},
            "ecriture": {"postale", "libelle"},
            "fin": {"ligne", "phrase"},
        }.items():
            self.assertEqual({d[axe] for d in self.docs}, valeurs)
            for v in valeurs:
                self.assertEqual(sum(d[axe] == v for d in self.docs),
                                 480 // len(valeurs))
        self.assertEqual({d["mots"] for d in self.docs}, {1, 2, 3, 4})

    def test_offsets_exacts(self):
        for d in self.docs:
            t = d["text"]
            e = d["entities"][0]
            adresse = t[e["start"]:e["end"]]
            self.assertRegex(adresse, r"^\d{5} \S", t)
            self.assertEqual(t[e["start"] - 1], "\n")
            # La suite commence un espace apres l'adresse, sur la meme ligne.
            self.assertEqual(d["suite"][0], e["end"] + 1)
            suite = t[slice(*d["suite"])]
            self.assertNotIn("\n", adresse + suite)
            self.assertEqual(suite, suite.strip())
            self.assertIn(suite, cs.SUITES_CAPITALES + cs.SUITES_MAJUSCULE
                          + cs.SUITES_LIAISON)
            if d["fin"] == "ligne":
                self.assertEqual(t[d["suite"][1]], "\n")
            else:
                self.assertRegex(t[d["suite"][1]:], r"^ [a-z]")

    def test_ecriture_postale_sans_minuscule_ni_accent(self):
        for d in self.docs:
            e = d["entities"][0]
            commune = d["text"][e["start"] + 6:e["end"]]
            self.assertEqual(len(re.split(r"[ -]", commune)), d["mots"])
            if d["ecriture"] == "postale":
                self.assertRegex(commune, r"^[A-Z ]+$")
            else:
                self.assertRegex(commune, r"[a-zà-ÿ]")

    def test_la_suite_ne_contient_ni_chiffres_longs_ni_cedex(self):
        for suite in (cs.SUITES_CAPITALES + cs.SUITES_MAJUSCULE
                      + cs.SUITES_LIAISON):
            self.assertNotRegex(suite, r"\d{2}|(?i:cedex)")


class ScoreTest(unittest.TestCase):
    DOC = {"id": 0, "text": "A :\n70000 VESOUL ET ENVIRONS\nMerci.",
           "entities": [{"type": "adresse", "start": 4, "end": 16}],
           "suite": [17, 28], "famille": "capitales", "ecriture": "postale",
           "fin": "ligne", "mots": 1}

    def test_suite_en_clair_et_adresse_couverte(self):
        pred = {"id": 0, "entities": [{"type": "adresse", "start": 4,
                                       "end": 16}]}
        self.assertEqual(sc.juge(self.DOC, pred), (10, 0, False))

    def test_suite_masquee_en_partie(self):
        pred = {"id": 0, "entities": [{"type": "adresse", "start": 4,
                                       "end": 19}]}
        self.assertEqual(sc.juge(self.DOC, pred), (10, 2, False))

    def test_adresse_en_clair(self):
        pred = {"id": 0, "entities": [{"type": "adresse", "start": 4,
                                       "end": 9}]}
        self.assertEqual(sc.juge(self.DOC, pred), (10, 0, True))

    def test_refus_compte_a_part(self):
        stats, refus = sc.compte(
            [self.DOC], {0: {"id": 0, "entities": [], "refuse": True}})
        self.assertEqual(refus, 1)
        self.assertEqual(stats[("tout", "")]["documents"], 0)


if __name__ == "__main__":
    unittest.main()
