"""Tests de `listes_exclusion.py` (P2-308) : l'extraction lit chaque liste, la
sonde est déterministe et annote un seul nom par document."""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import listes_exclusion as le  # noqa: E402


class ListesExclusion(unittest.TestCase):
    def test_chaque_liste_est_lue(self):
        for ident, fichier, nom, _ in le.LISTES:
            self.assertGreater(len(le.entrees(fichier, nom)), 0, ident)

    def test_tailles_connues(self):
        self.assertEqual(len(le.entrees("verbes_conjugues.dart", "verbesConjuguesCourants")), 558)
        self.assertEqual(len(le.entrees("name_detector.dart", "_statuts")), 59)

    def test_plie(self):
        self.assertEqual(le.plie("Marié"), "MARIE")
        self.assertEqual(le.plie("brûle"), "BRULE")

    def test_sonde_deterministe_et_un_nom_par_document(self):
        with tempfile.TemporaryDirectory() as d:
            a, b = os.path.join(d, "a.jsonl"), os.path.join(d, "b.jsonl")
            le.cmd_sonde(a, 5)
            le.cmd_sonde(b, 5)
            self.assertEqual(open(a, encoding="utf-8").read(), open(b, encoding="utf-8").read())
            for l in open(a, encoding="utf-8"):
                doc = json.loads(l)
                self.assertEqual(len(doc["entities"]), 1)
                e = doc["entities"][0]
                self.assertLessEqual(e["end"], len(doc["text"]))
                self.assertEqual(
                    doc["text"][doc["patro_debut"]:doc["patro_fin"]].lower(), doc["mot"].lower())


class HomonymesDart(unittest.TestCase):
    """P2-310 : le fichier Dart des homonymes de patronymes est celui que le
    script génère (aucune édition à la main, aucune dérive des listes)."""

    def test_fichier_a_jour(self):
        with open(le.FICHIER_HOMONYMES, encoding="utf-8") as f:
            self.assertEqual(f.read(), le.source_dart())

    def test_quelques_homonymes_connus(self):
        mots = set(le.mots_homonymes())
        for m in ("marie", "cadet", "avril", "porte", "gendre"):
            self.assertIn(m, mots)
        for m in ("beneficiaire", "rappelle"):
            self.assertNotIn(m, mots)


if __name__ == "__main__":
    unittest.main()
