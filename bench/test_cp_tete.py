#!/usr/bin/env python3
"""Tests du corpus « code postal en tete » (P2-177) :
`python3 -m unittest discover -s bench`. Donnees synthetiques."""

import gzip
import os
import re
import unicodedata
import unittest

import generate_corpus_cp_tete as ct

COMMUNES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                        "packages", "ecluse_reference", "assets",
                        "geo_communes.csv.gz")


class CorpusTest(unittest.TestCase):
    def test_reproductible_a_graine_egale(self):
        self.assertEqual(ct.construit(432, 42), ct.construit(432, 42))
        self.assertNotEqual(ct.construit(432, 42), ct.construit(432, 43))

    def test_une_adresse_annotee_par_document_offsets_exacts(self):
        docs = ct.construit(432, 42)
        self.assertEqual(len(docs), 432)
        for d in docs:
            self.assertEqual(len(d["entities"]), 1)
            e = d["entities"][0]
            self.assertEqual(e["type"], "adresse")
            valeur = d["text"][e["start"]:e["end"]]
            # Code postal, espace, commune ; rien d'autre dans le span.
            self.assertRegex(valeur, r"^\d{5} [^\s,.;()]+$", d["text"])

    def test_axes_couverts_a_parts_egales(self):
        docs = ct.construit(432, 42)
        for axe, valeurs in {
            "position": set(ct.POSITIONS),
            "suite": set(ct.SUITES),
            "casse": set(ct.CASSES),
        }.items():
            self.assertEqual({d[axe] for d in docs}, valeurs)
            for v in valeurs:
                self.assertEqual(sum(d[axe] == v for d in docs),
                                 432 // len(valeurs), (axe, v))

    def test_le_code_postal_ouvre_le_texte_une_ligne_ou_une_phrase(self):
        for d in ct.construit(432, 42):
            avant = d["text"][:d["entities"][0]["start"]]
            if d["position"] == "debut_texte":
                self.assertEqual(avant, "")
            elif d["position"] == "debut_ligne":
                self.assertTrue(avant.endswith("\n"), d["text"])
                # La ligne d'avant n'a pas de point final : bloc d'adresse ou
                # prose recoupee, pas une fin de phrase.
                self.assertNotRegex(avant, r"[.!?]\n$")
            else:
                self.assertRegex(avant, r"[.!?] $", d["text"])

    def test_suite_conforme_a_son_axe(self):
        for d in ct.construit(432, 42):
            apres = d["text"][d["entities"][0]["end"]:]
            if d["suite"] == "rien":
                self.assertEqual(apres, "")
            elif d["suite"] == "ligne":
                self.assertTrue(apres.startswith("\n"), d["text"])
            elif d["suite"] == "ponctuation":
                self.assertRegex(apres, r"^ ?[,.;(]", d["text"])
            else:
                self.assertRegex(apres, r"^ [a-zà-ÿ]", d["text"])

    def test_casse_minuscules_sans_aucune_majuscule(self):
        for d in ct.construit(432, 42):
            majuscules = re.findall(r"[A-ZÀ-ÖØ-Þ]", d["text"])
            if d["casse"] == "minuscules":
                self.assertEqual(majuscules, [], d["text"])
            else:
                self.assertNotEqual(majuscules, [], d["text"])

    def test_aucun_autre_nombre_de_cinq_chiffres(self):
        # Une seule suite de cinq chiffres par document : le code postal.
        for d in ct.construit(432, 42):
            self.assertEqual(
                len(re.findall(r"(?<!\d)\d{5}(?!\d)", d["text"])), 1, d["text"])


class HorsTableTest(unittest.TestCase):
    """Variante `--hors-table` (P2-184) : memes axes, noms absents de la
    table des communes."""

    @staticmethod
    def norme(nom):
        # Meme regle que `normName` d'`ecluse_reference`.
        sans = "".join(c for c in unicodedata.normalize("NFD", nom)
                       if unicodedata.category(c) != "Mn").upper()
        return " ".join(re.sub(r"['’\-./]", " ", sans).split())

    def test_aucun_nom_ni_debut_de_nom_dans_la_table(self):
        with gzip.open(COMMUNES, "rt", encoding="utf-8") as f:
            next(f)
            table = {l.rstrip("\n").split(";")[4] for l in f}
        self.assertGreater(len(table), 30000)
        for _, nom in ct.HORS_TABLE:
            mots = self.norme(nom).split()
            for k in range(1, len(mots) + 1):
                self.assertNotIn(" ".join(mots[:k]), table, nom)
        # Garde-fou du test lui-meme : les communes d'origine y sont.
        for _, nom in ct.COMMUNES:
            self.assertIn(self.norme(nom), table, nom)

    def test_memes_axes_et_memes_positions_que_le_corpus_d_origine(self):
        origine = ct.construit(432, 42)
        hors = ct.construit(432, 42, hors_table=True)
        self.assertEqual(len(hors), 432)
        self.assertEqual(hors, ct.construit(432, 42, hors_table=True))
        noms = {n for _, n in ct.HORS_TABLE}
        for a, b in zip(origine, hors):
            self.assertEqual((a["position"], a["suite"], a["casse"]),
                             (b["position"], b["suite"], b["casse"]))
            e = b["entities"][0]
            self.assertEqual(e["start"], a["entities"][0]["start"])
            valeur = b["text"][e["start"]:e["end"]]
            self.assertRegex(valeur, r"^\d{5} [^\s,.;()]+$")
            self.assertIn(valeur[6:].lower(), {n.lower() for n in noms})

    def test_le_corpus_d_origine_ne_change_pas(self):
        # L'option ajoutee ne consomme aucun tirage de plus.
        self.assertEqual(ct.construit(432, 42),
                         ct.construit(432, 42, hors_table=False))


if __name__ == "__main__":
    unittest.main()
