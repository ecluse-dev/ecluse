#!/usr/bin/env python3
"""Tests de score.py : `python3 -m unittest bench/test_score.py` (depuis la
racine) ou `python3 test_score.py` (depuis bench/). Données synthétiques."""

import unittest

import score


def ent(t, s, e):
    return {"type": t, "start": s, "end": e}


class ScoreTest(unittest.TestCase):
    def test_type_predit_non_annote_compte_en_faux_positif(self):
        gold = {0: [ent("nir", 0, 13)]}
        pred = {0: [ent("nir", 0, 13), ent("phone", 20, 30)]}
        types = score.TYPES + ["phone"]
        tp, fp, fn = score.evaluate(gold, pred, True, types)
        self.assertEqual(fp["phone"], 1)
        self.assertEqual(tp["nir"], 1)

    def test_souple_un_caractere_suffit_mais_la_fuite_le_montre(self):
        gold = {0: [ent("nir", 0, 13)]}
        pred = {0: [ent("nir", 12, 13)]}
        tp, fp, fn = score.evaluate(gold, pred, False)
        self.assertEqual(tp["nir"], 1)  # le mode souple est indulgent
        total, leaked = score.leakage(gold, pred, {"nir"})
        self.assertEqual((total["nir"], leaked["nir"]), (13, 12))
        tp, fp, fn = score.evaluate(gold, pred, True)
        self.assertEqual((tp["nir"], fp["nir"], fn["nir"]), (0, 1, 1))

    def test_aucune_fuite_quand_tout_est_couvert(self):
        gold = {0: [ent("iban", 5, 32)]}
        pred = {0: [ent("iban", 5, 32)]}
        total, leaked = score.leakage(gold, pred, {"iban"})
        self.assertEqual(leaked["iban"], 0)

    def test_couverture_par_un_autre_type_protege(self):
        gold = {0: [ent("rpps", 0, 11)]}
        pred = {0: [ent("finess", 0, 11)]}
        total, leaked = score.leakage(gold, pred, {"rpps"})
        self.assertEqual(leaked["rpps"], 0)


if __name__ == "__main__":
    unittest.main()
