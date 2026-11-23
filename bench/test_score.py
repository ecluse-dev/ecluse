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


class TypesCommunsTest(unittest.TestCase):
    """P2-261 : `siren` retiré de l'or et des prédictions, pour tous les moteurs."""

    def test_sans_entreprise_retire_seulement_siren(self):
        docs = {0: [ent("siren", 0, 9), ent("nir", 20, 35)], 1: [ent("siren", 3, 5)]}
        self.assertEqual(score.sans_entreprise(docs),
                         {0: [ent("nir", 20, 35)], 1: []})

    def test_meme_regle_des_deux_cotes(self):
        gold = {0: [ent("siren", 0, 9), ent("nir", 20, 35)]}
        pred = {0: [ent("finess", 0, 9), ent("nir", 20, 35)]}
        # tous types : le `finess` posé sur un SIREN est un faux positif et le
        # SIREN annoté est manqué
        types = score.TYPES + ["siren"]
        tp, fp, fn = score.evaluate(gold, pred, True, types)
        self.assertEqual((sum(tp.values()), sum(fp.values()), sum(fn.values())),
                         (1, 1, 1))
        # types communs : l'or `siren` est retiré ; un `finess` prédit reste
        # (la règle ne retire que le type `siren`)
        tp, fp, fn = score.evaluate(score.sans_entreprise(gold),
                                    score.sans_entreprise(pred), True)
        self.assertEqual((sum(tp.values()), sum(fp.values()), sum(fn.values())),
                         (1, 1, 0))
        # une prédiction `siren` est retirée aussi
        pred = {0: [ent("siren", 0, 9), ent("nir", 20, 35)]}
        tp, fp, fn = score.evaluate(score.sans_entreprise(gold),
                                    score.sans_entreprise(pred), True)
        self.assertEqual((sum(tp.values()), sum(fp.values()), sum(fn.values())),
                         (1, 0, 0))


if __name__ == "__main__":
    unittest.main()
