#!/usr/bin/env python3
"""Tests du corpus « code postal en tete » (P2-177) :
`python3 -m unittest discover -s bench`. Donnees synthetiques."""

import re
import unittest

import generate_corpus_cp_tete as ct


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


if __name__ == "__main__":
    unittest.main()
