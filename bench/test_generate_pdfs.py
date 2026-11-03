#!/usr/bin/env python3
"""Tests de generate_pdfs.py : `python3 -m unittest discover -s bench`
(depuis la racine) ou `python3 test_generate_pdfs.py` (depuis bench/).
Données synthétiques ; `pdftotext` n'est utilisé que s'il est installé."""

import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest

import generate_corpus as gc
import generate_pdfs as gp

HERE = os.path.dirname(os.path.abspath(__file__))


class GeneratePdfsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files, cls.meta = gp.build_all()

    def test_reproductible_octet_pour_octet(self):
        files2, meta2 = gp.build_all()
        self.assertEqual(self.files, files2)
        self.assertEqual(self.meta, meta2)

    def test_jeu_versionne_identique_a_la_generation(self):
        pdf_dir = os.path.join(HERE, "pdf")
        for name, data in self.files.items():
            with open(os.path.join(pdf_dir, name), "rb") as f:
                self.assertEqual(f.read(), data, name)
        with open(os.path.join(pdf_dir, "expected.json"), encoding="utf-8") as f:
            self.assertEqual(sorted(json.load(f)["fichiers"]), sorted(self.files))

    def test_attendus_complets_et_motifs_pour_les_refus(self):
        self.assertEqual(set(self.files), set(self.meta))
        for name, m in self.meta.items():
            self.assertIn(m["attendu"], {"accepte", "accepte_avertissement", "refuse"}, name)
            self.assertEqual("motif" in m, m["attendu"] == "refuse", name)
            if m["attendu"] == "accepte_avertissement":
                self.assertTrue(m.get("avertissements_attendus"), name)

    def test_identifiants_fabriques_valides(self):
        ids = gp.identifiers()
        nir, _ = ids["nir"]
        self.assertEqual(int(nir[13:]), gc.nir_key(nir[:13]))
        rpps, _ = ids["rpps"]
        self.assertEqual(gc.luhn_digit(rpps[:-1]), rpps)
        iban, _ = ids["iban"]
        self.assertEqual(int(iban[2:4]), gc.iban_check(iban[4:]))

    def test_xref_coherente_pour_les_pdf_intacts(self):
        broken = {"tronque.pdf", "xref_casse.pdf"}
        for name, data in self.files.items():
            if name in broken:
                continue
            start = int(re.search(rb"startxref\n(\d+)\n", data).group(1))
            self.assertTrue(data[start:].startswith(b"xref\n"), name)
            count = int(re.match(rb"xref\n0 (\d+)\n", data[start:]).group(1))
            entries = re.findall(rb"(\d{10}) 00000 n \n", data[start:])
            self.assertEqual(len(entries), count - 1, name)
            for num, off in enumerate(entries, start=1):
                self.assertTrue(
                    data[int(off):].startswith(b"%d 0 obj\n" % num), (name, num))

    def test_pdf_tronque_sans_trailer_et_xref_casse_pointe_ailleurs(self):
        self.assertNotIn(b"trailer", self.files["tronque.pdf"])
        data = self.files["xref_casse.pdf"]
        start = int(re.search(rb"startxref\n(\d+)\n", data).group(1))
        self.assertFalse(data[start:].startswith(b"xref\n"))

    def test_chiffre_porte_un_dictionnaire_encrypt(self):
        self.assertIn(b"/Encrypt", self.files["chiffre.pdf"])
        self.assertNotIn(b"Compte rendu", self.files["chiffre.pdf"])

    def test_aucun_identifiant_en_clair_dans_le_pdf_chiffre(self):
        _, nir_txt = gp.identifiers()["nir"]
        self.assertNotIn(nir_txt.encode(), self.files["chiffre.pdf"])

    @unittest.skipUnless(shutil.which("pdftotext"), "pdftotext absent")
    def test_texte_extrait_contient_les_identifiants_attendus(self):
        with tempfile.TemporaryDirectory() as tmp:
            for name in ("texte_simple.pdf", "texte_multipage.pdf",
                         "texte_colonnes.pdf", "chiffre.pdf"):
                path = os.path.join(tmp, name)
                with open(path, "wb") as f:
                    f.write(self.files[name])
                out = subprocess.run(["pdftotext", path, "-"], capture_output=True,
                                     text=True, check=True).stdout
                ref = "texte_simple.pdf" if name == "chiffre.pdf" else name
                for e in self.meta[ref]["entites"]:
                    self.assertIn(e["affiche"], out, (name, e["type"]))

    @unittest.skipUnless(shutil.which("pdftotext"), "pdftotext absent")
    def test_scan_pur_sans_texte(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "scan.pdf")
            with open(path, "wb") as f:
                f.write(self.files["scan_pur.pdf"])
            out = subprocess.run(["pdftotext", path, "-"], capture_output=True,
                                 text=True, check=True).stdout
            self.assertEqual(out.strip(), "")


if __name__ == "__main__":
    unittest.main()
