"""Tests du corpus « identifiant suivi d'un nombre » et de son scoreur
(P2-174). Donnees synthetiques, cles calculees."""

import unittest

from generate_corpus import luhn_digit, nir_key
from generate_corpus_identifiant_suivi import (FAMILLES, SEPARATEURS, TYPES,
                                               construit)
from score_identifiant_suivi import juge, mesure


class Generateur(unittest.TestCase):
    def setUp(self):
        self.docs = construit(5, 42)

    def test_reproductible_a_graine_egale(self):
        self.assertEqual(self.docs, construit(5, 42))
        self.assertNotEqual(self.docs, construit(5, 7))

    def test_effectif_par_axe(self):
        self.assertEqual(len(self.docs),
                         5 * len(TYPES) * len(FAMILLES) * len(SEPARATEURS))
        for t in TYPES:
            self.assertEqual(sum(d["type_id"] == t for d in self.docs),
                             5 * len(FAMILLES) * len(SEPARATEURS))

    def test_offsets_et_cles(self):
        for d in self.docs:
            e = d["entities"][0]
            valeur = d["text"][e["start"]:e["end"]]
            chiffres = "".join(c for c in valeur if c.isalnum())
            if d["type_id"] == "finess":
                self.assertEqual(len(chiffres), 9)
                self.assertEqual(luhn_digit(chiffres[:-1]), chiffres)
            elif d["type_id"] == "rpps":
                self.assertEqual(len(chiffres), 11)
                self.assertEqual(luhn_digit(chiffres[:-1]), chiffres)
            elif d["type_id"] == "nir":
                self.assertEqual(len(chiffres), 15)
                self.assertEqual(f"{nir_key(chiffres[:13]):02d}", chiffres[13:])
            else:
                self.assertTrue(chiffres.startswith("FR"))
                self.assertEqual(len(chiffres), 27)

    def test_la_suite_commence_par_un_chiffre_juste_apres_le_separateur(self):
        for d in self.docs:
            e, s = d["entities"][0], d["suite"]
            self.assertEqual(d["text"][e["end"]:s["start"]],
                             SEPARATEURS[d["separateur"]])
            self.assertTrue(d["text"][s["start"]].isdigit())
            self.assertTrue(d["text"][e["end"] - 1].isdigit())


class Scoreur(unittest.TestCase):
    def setUp(self):
        t = "FINESS 123456782 12/03/2024 noté au dossier."
        self.doc = {"id": 0, "text": t,
                    "entities": [{"type": "finess", "start": 7, "end": 16}],
                    "suite": {"start": 17, "end": 27}, "type_id": "finess",
                    "famille": "date_chiffres", "separateur": "espace",
                    "contexte": "mot_cle"}

    def pred(self, *entites):
        return {"id": 0, "entities": [
            {"type": t, "start": s, "end": e} for t, s, e in entites]}

    def test_juste(self):
        r = juge(self.doc, self.pred(("finess", 7, 16)))
        self.assertTrue(r["couvert"] and r["type_juste"])
        self.assertFalse(r["suite_avalee"])

    def test_non_couvert(self):
        r = juge(self.doc, self.pred())
        self.assertFalse(r["couvert"])
        self.assertFalse(r["type_juste"])

    def test_type_faux_et_suite_avalee(self):
        r = juge(self.doc, self.pred(("rpps", 7, 19)))
        self.assertTrue(r["couvert"])
        self.assertFalse(r["type_juste"])
        self.assertTrue(r["suite_avalee"])

    def test_couverture_partielle_est_une_fuite(self):
        r = juge(self.doc, self.pred(("rpps", 10, 19)))
        self.assertFalse(r["couvert"])

    def test_suite_masquee_par_une_autre_detection(self):
        r = juge(self.doc, self.pred(("finess", 7, 16),
                                     ("date_naissance", 17, 27)))
        self.assertTrue(r["type_juste"])
        self.assertFalse(r["suite_avalee"])
        self.assertTrue(r["suite_masquee"])

    def test_mesure_compte_les_defauts(self):
        total, par_axe, confusions = mesure(
            [self.doc], [self.pred(("rpps", 7, 19))])
        self.assertEqual(total["en_defaut"], 1)
        self.assertEqual(par_axe["type_id"]["finess"]["en_defaut"], 1)
        self.assertEqual(
            confusions[("finess", "rpps", "date_chiffres", "espace")], 1)


if __name__ == "__main__":
    unittest.main()
