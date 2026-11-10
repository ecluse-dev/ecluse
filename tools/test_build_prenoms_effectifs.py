"""Tests de `build_prenoms_effectifs.py` sur des fichiers synthetiques.

Aucune donnee de l'INSEE n'est versionnee ici : prenoms et effectifs sont
inventes, seule la forme des colonnes est reprise.

    python3 -m unittest tools/test_build_prenoms_effectifs.py
"""

import gzip
import os
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, os.path.dirname(__file__))
import build_prenoms_effectifs as b  # noqa: E402

CSV_POINT_VIRGULE = (
    "sexe;prenom;periode;valeur\n"
    "1;OLEKSANDR;2000;40\n"
    "1;OLEKSANDR;2001;35\n"
    "2;Hélène;1950;100\n"
    "2;HELENE;1951;5\n"
    "1;_PRENOMS_RARES;2000;9999\n"
    "1;AL;2000;50\n"
    "2;Mei-Ling;2010;5\n"
)


class Tests(unittest.TestCase):
    def test_somme_par_prenom_normalise(self):
        t = b.effectifs(CSV_POINT_VIRGULE)
        self.assertEqual(t["OLEKSANDR"], 75)
        self.assertEqual(t["HELENE"], 105)
        self.assertEqual(t["MEI LING"], 5)

    def test_regroupement_et_formes_courtes_ecartes(self):
        t = b.effectifs(CSV_POINT_VIRGULE)
        self.assertNotIn("PRENOMS RARES", t)
        self.assertNotIn("_PRENOMS_RARES", t)
        self.assertNotIn("AL", t)

    def test_virgule_et_intitules_differents(self):
        t = b.effectifs("SEXE,PREUSUEL,ANNAIS,NOMBRE\n1,BINTOU,1990,12\n")
        self.assertEqual(t, {"BINTOU": 12})

    def test_seul_le_niveau_national_est_lu(self):
        t = b.effectifs("sexe;prenom;periode;niveau_geographique;geographie;"
                        "valeur;rang\n"
                        "1;BINTOU;2000;FRANCE;F;20;1\n"
                        "1;BINTOU;2000;REG;11;20;1\n"
                        "1;BINTOU;2000;DEP;75;20;1\n")
        self.assertEqual(t, {"BINTOU": 20})

    def test_colonnes_inconnues_refusees(self):
        with self.assertRaises(SystemExit):
            b.effectifs("a;b;c\n1;2;3\n")

    def test_effectif_illisible_refuse(self):
        with self.assertRaises(SystemExit):
            b.effectifs("prenom;valeur\nBINTOU;beaucoup\n")

    def test_zip_et_sortie_deterministe(self):
        with tempfile.TemporaryDirectory() as d:
            z = os.path.join(d, "nat.zip")
            with zipfile.ZipFile(z, "w") as zf:
                zf.writestr("nat.csv", CSV_POINT_VIRGULE)
            s1, s2 = os.path.join(d, "a.gz"), os.path.join(d, "b.gz")
            b.main([z, s1, "--libelle", "essai"])
            b.main([z, s2, "--libelle", "essai"])
            with open(s1, "rb") as f1, open(s2, "rb") as f2:
                self.assertEqual(f1.read(), f2.read())
            lignes = gzip.open(s1, "rt", encoding="utf-8").read().splitlines()
            self.assertTrue(lignes[0].startswith("# Source : Insee, essai"))
            self.assertEqual(lignes[1:], ["HELENE\t105", "MEI LING\t5",
                                          "OLEKSANDR\t75"])

    def test_parite_de_normalisation(self):
        sys.path.insert(0, os.path.dirname(__file__))
        src = open(os.path.join(os.path.dirname(__file__),
                                "build_reference_assets.py"),
                   encoding="utf-8").read()
        debut = src.index("def norm_name")
        fin = src.index("\ndef ", debut + 1)
        espace = {}
        exec("import unicodedata\n" + src[debut:fin], espace)
        for s in ["Hélène", "Mei-Ling", "N'Golo", "Anne.Marie", "Łukasz"]:
            self.assertEqual(b.norm_name(s), espace["norm_name"](s), s)


if __name__ == "__main__":
    unittest.main()
