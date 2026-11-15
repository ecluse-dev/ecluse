"""Tests du classement des communes en capitales (P2-196)."""

import unittest

from classe_communes_capitales import classe, mots_neutres


class Classement(unittest.TestCase):
    def setUp(self):
        self.neutres = mots_neutres()

    def test_la_liste_est_lue_dans_le_detecteur(self):
        for mot in ("le", "euros", "sur", "d"):
            self.assertIn(mot, self.neutres)

    def test_les_cinq_formes(self):
        cas = {
            "VERS PONT DU GARD": "mot neutre en tête",
            "D HUISON LONGUEVILLE": "mot neutre en tête",
            "CHATEAU CHINON (VILLE)": "parenthèse",
            "SARROUX - SAINT JULIEN": "tiret ou blancs entre deux noms",
            "SAINT PATERNE   LE CHEVAIN": "tiret ou blancs entre deux noms",
            "LES PLACES": "déterminant puis mot neutre",
            "SAINT JULIEN": "autre",
        }
        for nom, attendu in cas.items():
            with self.subTest(nom=nom):
                self.assertEqual(classe(nom, self.neutres), attendu)


if __name__ == "__main__":
    unittest.main()
