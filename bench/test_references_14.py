"""Tests de `generate_corpus_references_14.py` et `analyse_references_14.py`
(P2-311) : corpus déterministe, aucune entité annotée, une référence par
document, clé de Luhn notée exactement."""
import json
import os
import subprocess
import sys
import tempfile
import unittest

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import generate_corpus_references_14 as g  # noqa: E402


def genere(out, n=20, seed=42):
    subprocess.run([sys.executable, os.path.join(ICI, "generate_corpus_references_14.py"),
                    "--n", str(n), "--seed", str(seed), "--out", out],
                   check=True, capture_output=True)
    return [json.loads(l) for l in open(out, encoding="utf-8")]


class References14(unittest.TestCase):
    def test_deterministe(self):
        with tempfile.TemporaryDirectory() as d:
            a, b = os.path.join(d, "a"), os.path.join(d, "b")
            genere(a)
            genere(b)
            self.assertEqual(open(a, encoding="utf-8").read(), open(b, encoding="utf-8").read())

    def test_structure(self):
        with tempfile.TemporaryDirectory() as d:
            docs = genere(os.path.join(d, "c"), n=30)
        self.assertEqual(len(docs), 30 * len(g.FORMES))
        for doc in docs:
            self.assertEqual(doc["entities"], [])
            if doc["forme"] == "sans_reference":
                self.assertNotIn("ref", doc)
                continue
            r = doc["ref"]
            ecrit = doc["text"][r["start"]:r["end"]]
            if "luhn" in r:
                chiffres = "".join(c for c in ecrit if c.isdigit())
                self.assertEqual(len(chiffres), 14)
                self.assertEqual(r["luhn"], g.luhn_ok(chiffres))
            else:
                self.assertTrue(ecrit.startswith("FR"))
                self.assertEqual(len(ecrit), 13)

    def test_tva_cle_fausse_est_fausse(self):
        with tempfile.TemporaryDirectory() as d:
            docs = genere(os.path.join(d, "c"), n=50)
        for doc in docs:
            if doc["forme"] == "tva_cle_fausse":
                r = doc["ref"]
                ecrit = doc["text"][r["start"]:r["end"]]
                self.assertNotEqual(int(ecrit[2:4]), g.cle_tva(ecrit[4:]))


if __name__ == "__main__":
    unittest.main()
