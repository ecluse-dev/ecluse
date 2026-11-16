"""Tests du classement des communes en capitales (P2-196)."""

import unittest

from classe_communes_capitales import classe, forme_sans_cedex, mots_neutres


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


class FormesSansCedex(unittest.TestCase):
    """Ventilation A a E de P2-206 : une seule forme par adresse."""

    def setUp(self):
        self.n = mots_neutres()

    def test_les_cinq_formes(self):
        cas = [
            ("FLAVIGNY LE GRAND ET BEAURAIN", 5, False, "A"),
            ("LA ROCHE SUR LE BUIS", 5, False, "A"),  # determinant : pas B
            ("SON", 1, False, "B"),
            ("SOUS PARSAT", 2, False, "B"),
            ("SARROUX - SAINT JULIEN", 3, False, "C"),
            ("CHATEAU CHINON (VILLE)", 3, False, "C"),
            ("LES PLACES", 2, False, "D"),
            ("MAS CABARDES", 2, True, "E"),
            ("SAINT JULIEN", 2, False, "autre"),
        ]
        for nom, mots, etab, attendu in cas:
            with self.subTest(nom=nom):
                self.assertEqual(
                    forme_sans_cedex(nom, mots, etab, self.n), attendu)

    def test_l_etablissement_prime_sur_la_forme(self):
        self.assertEqual(forme_sans_cedex("SON", 1, True, self.n), "E")

    def test_une_parenthese_de_cinq_mots_est_c_pas_a(self):
        self.assertEqual(forme_sans_cedex(
            "BORS (CANTON DE TUDE ET LAVALETTE)", 7, False, self.n), "C")


if __name__ == "__main__":
    unittest.main()
