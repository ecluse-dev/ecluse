#!/usr/bin/env python3
"""Tests du generateur « mise en page » (P2-153) : `python3 -m unittest
discover -s bench` (depuis la racine). Donnees synthetiques."""

import json
import os
import subprocess
import sys
import tempfile
import unittest

import generate_corpus_mise_en_page as gen

ICI = os.path.dirname(os.path.abspath(__file__))
DOCS = [
    {"id": 0, "text": "Rendez-vous avec Mme Camille Verdier au 12 rue des "
                      "Lilas, 69003 Lyon, demain matin.",
     "entities": [{"type": "nom", "start": 15, "end": 36},
                  {"type": "adresse", "start": 40, "end": 74}]},
    {"id": 1, "text": "Ligne un\nligne deux assez longue pour etre coupee "
                      "ici meme", "entities": []},
    {"id": 2, "text": "NIR 1 85 05 78 006 084 36 envoye", "entities": []},
]


class TestMiseEnPage(unittest.TestCase):
    def test_longueur_et_contenu_conserves(self):
        for d in DOCS:
            for largeur in (10, 60, 90):
                t = gen.recoupe(d["text"], largeur)
                self.assertEqual(len(t), len(d["text"]))
                self.assertEqual(t.replace("\n", " "),
                                 d["text"].replace("\n", " "))

    def test_offsets_et_caracteres_hors_blanc_identiques(self):
        for d in DOCS:
            t = gen.transforme(d, 20)
            self.assertEqual(t["entities"], d["entities"])
            for e in d["entities"]:
                a = d["text"][e["start"]:e["end"]]
                b = t["text"][e["start"]:e["end"]]
                self.assertEqual(a.split(), b.split())
            for x, y in zip(d["text"], t["text"]):
                if x != y:
                    self.assertEqual((x, y), (" ", "\n"))

    def test_largeur_respectee_sauf_mot_long(self):
        t = gen.recoupe(DOCS[0]["text"], 30)
        for ligne in t.split("\n"):
            self.assertLessEqual(len(ligne), 30)
        t = gen.recoupe("a supercalifragilistic b", 5)
        self.assertEqual(t, "a\nsupercalifragilistic\nb")

    def test_insecables_et_sauts_existants_intouches(self):
        t = gen.recoupe(DOCS[2]["text"], 8)
        self.assertIn("1 85 05", t)
        self.assertEqual(gen.recoupe("ab\ncd ef", 5), "ab\ncd ef")

    def test_un_nom_est_coupe_a_largeur_etroite(self):
        t = gen.recoupe(DOCS[0]["text"], 30)
        self.assertIn("Camille\nVerdier", t)

    def test_reproductible(self):
        with tempfile.TemporaryDirectory() as tmp:
            src = os.path.join(tmp, "c.jsonl")
            with open(src, "w", encoding="utf-8") as f:
                for d in DOCS:
                    f.write(json.dumps(d, ensure_ascii=False) + "\n")
            sorties = []
            for k in range(2):
                out = os.path.join(tmp, f"o{k}.jsonl")
                subprocess.run([sys.executable, os.path.join(
                    ICI, "generate_corpus_mise_en_page.py"), src,
                    "--largeur", "60", "--out", out, "--seed", "42"],
                    check=True, capture_output=True)
                with open(out, encoding="utf-8") as g:
                    sorties.append(g.read())
            self.assertEqual(sorties[0], sorties[1])


class TestRappelStructurel(unittest.TestCase):
    def test_couvert_quel_que_soit_le_type_et_blancs_ignores(self):
        import rappel_structurel as rs
        corpus = [{"id": 0, "text": "NIR 1 85 05\n78 006 084 36 et RPPS 10000000001",
                   "entities": [{"type": "NIR", "start": 4, "end": 25},
                                {"type": "RPPS", "start": 34, "end": 45}]}]
        pred = [{"id": 0, "entities": [{"type": "nir", "start": 4, "end": 11},
                                       {"type": "nir", "start": 12, "end": 25}]}]
        self.assertEqual(rs.rappel(corpus, pred),
                         {"nir": (1, 1), "rpps": (0, 1)})


if __name__ == "__main__":
    unittest.main()
