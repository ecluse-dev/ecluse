"""Tests de `build_patronymes_effectifs.py` sur des fichiers synthetiques.

Aucune donnee de l'INSEE n'est versionnee ici : noms et effectifs sont
inventes, seule la forme des colonnes est reprise.

    python3 -m unittest tools/test_build_patronymes_effectifs.py
"""

import gzip
import os
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, os.path.dirname(__file__))
import build_patronymes_effectifs as b  # noqa: E402

TEXTE = (
    "NOM\t_1891_1900\t_1901_1910\t_1991_2000\r\n"
    "KERVALOU\t1\t2\t3\r\n"
    "LE GALLIC\t0\t5\t5\r\n"
    "D'ARVENE\t2\t0\t0\r\n"
    "DARVENE\t1\t0\t0\r\n"
    "MARTIN-ZELOU\t4\t0\t1\r\n"
    "AUTRES NOMS\t9999\t9999\t9999\r\n"
    "X\t40\t0\t0\r\n"
)


class Tests(unittest.TestCase):
    def test_somme_par_nom_normalise(self):
        t = b.effectifs(TEXTE)
        self.assertEqual(t["KERVALOU"], 6)
        self.assertEqual(t["LE GALLIC"], 10)
        self.assertEqual(t["MARTIN ZELOU"], 5)
        self.assertEqual(t["D ARVENE"], 2)
        self.assertEqual(t["DARVENE"], 1)

    def test_regroupement_et_formes_courtes_ecartes(self):
        t = b.effectifs(TEXTE)
        self.assertNotIn("AUTRES NOMS", t)
        self.assertNotIn("X", t)

    def test_entete_inconnu_refuse(self):
        with self.assertRaises(SystemExit):
            b.effectifs("prenom\tvaleur\nKERVALOU\t3\n")

    def test_nombre_de_champs_refuse(self):
        with self.assertRaises(SystemExit):
            b.effectifs("NOM\t_1891_1900\t_1901_1910\nKERVALOU\t1\n")

    def test_effectif_illisible_refuse(self):
        with self.assertRaises(SystemExit):
            b.effectifs("NOM\t_1891_1900\nKERVALOU\tdeux\n")

    def test_zip_et_sortie_deterministe(self):
        with tempfile.TemporaryDirectory() as d:
            z = os.path.join(d, "noms.zip")
            with zipfile.ZipFile(z, "w") as zf:
                zf.writestr("noms.txt", TEXTE)
            sorties = []
            for i in range(2):
                s = os.path.join(d, f"s{i}.tsv.gz")
                b.ecrire(b.effectifs(b.lire_texte(z)), s, "essai")
                with open(s, "rb") as f:
                    sorties.append(f.read())
            self.assertEqual(sorties[0], sorties[1])
            lignes = gzip.decompress(sorties[0]).decode().splitlines()
            self.assertTrue(lignes[0].startswith("# Source : Insee, essai"))
            self.assertIn("KERVALOU\t6", lignes)


if __name__ == "__main__":
    unittest.main()
