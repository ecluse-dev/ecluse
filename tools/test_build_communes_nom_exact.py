"""Tests de `build_communes_nom_exact.py` (P2-214).

Lignes synthetiques au format du referentiel, plus un controle de parite du
fichier Dart versionne (le meme controle tourne en CI cote Dart :
`adresse_capitales_nom_exact_test.dart`).

    python3 -m unittest tools/test_build_communes_nom_exact.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import build_communes_nom_exact as b  # noqa: E402

NEUTRES = {"le", "la", "les", "l", "sous", "vers", "places", "en", "et"}
LIGNES = [
    "1;02;32;10;DHUYS ET MORIN EN BRIE;Dhuys et Morin-en-Brie\n",
    "2;58;27;10;CHATEAU CHINON (VILLE);Château-Chinon (Ville)\n",
    "3;15;84;10;SARROUX SAINT JULIEN;Sarroux - Saint Julien\n",
    "4;80;32;10;LES PLACES;Les Places\n",
    "5;09;76;10;SOUS PARSAT;Sous-Parsat\n",
    "6;46;76;10;VERS SUR UN MOT DE PLUS;Vers-sur-un-Mot-de-Plus\n",
    "7;70;27;10;VESOUL;Vesoul\n",
    "8;26;84;10;LA ROCHE SUR LE BUIS;La Roche-sur-le-Buis\n",
    "trop;court\n",
]


class Selection(unittest.TestCase):
    def test_formes_retenues_et_forme_b_ecartee(self):
        table = b.selectionne(LIGNES, NEUTRES)
        self.assertEqual(table, {
            "DHUYS ET MORIN EN BRIE": "A",
            "CHATEAU CHINON VILLE": "C",
            "SARROUX SAINT JULIEN": "C",
            "LES PLACES": "D",
            "LA ROCHE SUR LE BUIS": "A",
        })

    def test_cle_sans_ponctuation(self):
        self.assertEqual(b.cle("BORS (CANTON DE CHARENTE SUD)"),
                         "BORS CANTON DE CHARENTE SUD")

    def test_sortie_dart_triee_et_deterministe(self):
        table = b.selectionne(LIGNES, NEUTRES)
        dart = b.rend_dart(table)
        self.assertEqual(dart, b.rend_dart(dict(reversed(table.items()))))
        noms = [l.strip(" ',") for l in dart.splitlines()
                if l.startswith("  '")]
        self.assertEqual(noms, sorted(table))
        self.assertIn("const int communesNomExactMotsMax = 5;", dart)

    def test_le_fichier_versionne_est_a_jour(self):
        with open(b.SORTIE, encoding="utf-8") as f:
            self.assertEqual(f.read(), b.construit(),
                             "relancer tools/build_communes_nom_exact.py")


if __name__ == "__main__":
    unittest.main()
