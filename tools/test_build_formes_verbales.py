"""Tests de `build_formes_verbales.py` sur un CSV synthetique.

Aucune ligne de Morphalou n'est versionnee ici : seule la forme des colonnes
est reprise.

    python3 -m unittest tools/test_build_formes_verbales.py
"""

import gzip
import os
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, os.path.dirname(__file__))
import build_formes_verbales as b  # noqa: E402

CSV = (
    "en-tete libre\r\n"
    "LEMME;;;;;;;;;FLEXION;;;;;;;;\r\n"
    "GRAPHIE;ID;CATÉGORIE;SOUS CATÉGORIE;LOCUTION;GENRE;AUTRES;PHON;ORIG;"
    "GRAPHIE;ID;NOMBRE;MODE;GENRE;TEMPS;PERSONNE;PHON;ORIG\r\n"
    "zorpler;1;Verbe;;;-;;;;zorpler;1;-;infinitive;-;-;-;;\r\n"
    ";;;;;;;;;zorple;2;singular;indicative;-;present;thirdPerson;;\r\n"
    ";;;;;;;;;zorplé;3;singular;participle;masculine;past;-;;\r\n"
    "bivule;2;Nom commun;;;feminine;;;;bivule;4;singular;-;-;-;-;;\r\n"
    "avoir lieu;3;Verbe;;oui;-;;;;avoir lieu;5;-;infinitive;-;-;-;;\r\n"
)


class Tests(unittest.TestCase):
    def test_seules_les_formes_de_verbes(self):
        formes, nb = b.formes_verbales(CSV)
        self.assertEqual(formes, {"zorpler", "zorple", "zorplé"})
        self.assertEqual(nb, 1)

    def test_entete_absent_refuse(self):
        with self.assertRaises(SystemExit):
            b.formes_verbales("a;b;c\n1;2;3\n")

    def test_ligne_trop_courte_refusee(self):
        with self.assertRaises(SystemExit):
            b.formes_verbales("GRAPHIE;ID;CATÉGORIE\nzorpler;1;Verbe\n")

    def test_zip_et_sortie_deterministe(self):
        with tempfile.TemporaryDirectory() as d:
            z = os.path.join(d, "m.zip")
            with zipfile.ZipFile(z, "w") as zf:
                zf.writestr("m/M.csv", CSV)
            sorties = []
            for i in range(2):
                s = os.path.join(d, f"s{i}.gz")
                f, nb = b.formes_verbales(b.lire_texte(z))
                b.ecrire(f, nb, s, "2026-11-21")
                with open(s, "rb") as fh:
                    sorties.append(fh.read())
            self.assertEqual(sorties[0], sorties[1])
            lignes = gzip.decompress(sorties[0]).decode().splitlines()
            self.assertIn("LGPL-LR", lignes[1])
            self.assertIn("2026-11-21", lignes[2])
            self.assertEqual(lignes[3:], ["zorple", "zorpler", "zorplé"])


if __name__ == "__main__":
    unittest.main()
