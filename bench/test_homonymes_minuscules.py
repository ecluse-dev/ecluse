"""Tests de `analyse_homonymes_minuscules.py` (P2-314) : les filtres d'options
sont de la logique pure sur des phrases synthétiques ; aucun texte réel."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analyse_homonymes_minuscules as A  # noqa: E402


class TestOptions(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ctx = A.Ctx()

    def test_positions_lues_dans_l_avertissement(self):
        w = ("mot pris pour un nom commun derrière un prénom, une civilité ou « le "
             "dossier de », non masqué : à vérifier (2 occurrences, positions 7, 30).")
        self.assertEqual(A.positions(w), [7, 30])
        self.assertEqual(A.positions("sans position"), [])

    def test_chemin_minuscules(self):
        self.assertTrue(A.chemin_minuscules("sophie rappelle le service", 7))
        # Un mot capitalisé : autre chemin (civilité, « le dossier de »).
        self.assertFalse(A.chemin_minuscules("Sophie Rappelle le service", 7))
        self.assertFalse(A.chemin_minuscules("Madame Marié est venue", 8))

    def test_options_ne_touchent_que_le_chemin_minuscule(self):
        texte = "Madame Marié est venue"
        for o in A.OPTIONS:
            self.assertTrue(
                not A.chemin_minuscules(texte, 8), o)  # jamais filtré

    def test_o1_seuil_de_frequence(self):
        texte = "sophie rappelle le service"
        eff = self.ctx.patro.get(A.L.plie("rappelle"), 0)
        self.assertTrue(A.garde("O1(1)", self.ctx, texte, 7) == (eff >= 1))
        self.assertFalse(A.garde("O1(999999999)", self.ctx, texte, 7))

    def test_o3_retire_toujours_le_mot(self):
        self.assertFalse(A.garde("O3", self.ctx, "sophie rappelle", 7))
        self.assertTrue(A.garde("base", self.ctx, "sophie rappelle", 7))

    def test_o5_verbe_atteste(self):
        # « rappelle » est une forme verbale attestée du lexique.
        self.assertFalse(A.garde("O5", self.ctx, "sophie rappelle", 7))

    def test_minuscules_refuse_un_changement_de_longueur(self):
        self.assertEqual(A.minuscules({"text": "Sophie É"})["text"], "sophie é")


if __name__ == "__main__":
    unittest.main()
