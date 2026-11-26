"""Tests de la sonde de tableaux et de l'analyse de P2-296 (mesure)."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import analyse_tableaux_faux as a  # noqa: E402
import generate_sonde_tableaux as g  # noqa: E402


class SondeTableaux(unittest.TestCase):
    def test_deterministe_et_offsets_exacts(self):
        import random
        d1 = g.jeu(random.Random(42), False)
        d2 = g.jeu(random.Random(42), False)
        self.assertEqual(d1, d2)
        self.assertEqual(len(d1), 13 * g.NB_PAR_VARIANTE)
        for d in d1:
            for e in d["entities"]:
                cellule = d["text"][e["start"]:e["end"]]
                self.assertTrue(cellule)
                self.assertNotIn("\n", cellule)
                self.assertNotIn(";", cellule)

    def test_irreguliers_ont_une_ligne_de_trop(self):
        import random
        docs = g.jeu(random.Random(42), True)
        self.assertEqual(len(docs), 11 * g.NB_PAR_VARIANTE)
        for d in docs:
            if d["variante"] == "html":
                lignes = [l for l in d["text"].split("\n") if l.startswith("<tr><td>")]
                self.assertEqual(sorted({l.count("<td>") for l in lignes}), [2, 3])
            else:
                self.assertIn("à revoir", d["text"])


class Couverture(unittest.TestCase):
    def test_couvert_par_union(self):
        e = {"start": 10, "end": 20}
        self.assertTrue(a.couvert(e, [{"start": 8, "end": 22}]))
        self.assertTrue(a.couvert(e, [{"start": 10, "end": 14},
                                      {"start": 14, "end": 20}]))
        self.assertFalse(a.couvert(e, [{"start": 10, "end": 19}]))
        self.assertFalse(a.couvert(e, [{"start": 11, "end": 20}]))
        self.assertFalse(a.couvert(e, []))

    def test_analyse_compte_refus_et_envois_a_tort(self):
        corpus = [
            {"id": 0, "entities": [{"start": 0, "end": 3}]},
            {"id": 1, "entities": [{"start": 0, "end": 3}]},
            {"id": 2, "entities": [{"start": 0, "end": 3}]},
        ]
        pred = [
            {"id": 0, "entities": [{"start": 0, "end": 3}]},
            {"id": 1, "entities": [], "refuse": True},
            {"id": 2, "entities": []},
        ]
        refuses, annot, couv, tort = a.analyse(corpus, pred)
        self.assertEqual((refuses, annot, couv, tort), ([1], 2, 1, [2]))


if __name__ == "__main__":
    unittest.main()
