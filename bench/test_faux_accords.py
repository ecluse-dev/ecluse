"""P2-279 : scoreur des faux accords par détecteur (`score_faux_accords.py`).
Corpus synthétique ; aucune valeur réelle."""
import json
import os
import subprocess
import sys
import tempfile
import unittest

ICI = os.path.dirname(os.path.abspath(__file__))


class FauxAccordsTest(unittest.TestCase):
    def lance(self, corpus, pred, *options):
        with tempfile.TemporaryDirectory() as d:
            c, p = os.path.join(d, "c.jsonl"), os.path.join(d, "p.jsonl")
            for chemin, docs in ((c, corpus), (p, pred)):
                with open(chemin, "w", encoding="utf-8") as f:
                    for x in docs:
                        f.write(json.dumps(x) + "\n")
            return subprocess.run(
                [sys.executable, os.path.join(ICI, "score_faux_accords.py"),
                 "--corpus", c, "--pred", p, *options],
                capture_output=True, text=True)

    def test_attribution_et_intervalle(self):
        corpus = [{"id": i, "text": f"Réf {i}", "entities": []} for i in range(4)]
        pred = [
            {"id": 0, "e": [["iban", 0.3, ""]]},
            {"id": 1, "e": [["nir", 0.3, ""], ["nir", 0.3, ""]]},
            {"id": 2, "e": [["nir", 0.3, "lectureOcr"]]},
            {"id": 3, "e": []},
        ]
        r = self.lance(corpus, pred)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("IBAN à clé fausse (P2-252) : 1 / 4 documents", r.stdout)
        # Deux entités NIR dans un seul document : un document, deux entités.
        self.assertIn("NIR à clé fausse (P2-258) : 1 / 4 documents", r.stdout)
        self.assertIn("2 entité(s)", r.stdout)
        self.assertIn("OCR (P2-268) : 1 / 4 documents", r.stdout)
        self.assertIn("IC 95 %", r.stdout)

    def test_aucun_detecteur_donne_une_borne_haute(self):
        corpus = [{"id": i, "text": "x", "entities": []} for i in range(100)]
        pred = [{"id": i, "e": []} for i in range(100)]
        r = self.lance(corpus, pred)
        self.assertIn("aucun détecteur : 0 / 100 documents", r.stdout)
        self.assertIn("3.69", r.stdout)  # borne haute de Wilson ≈ 3,70 %

    def test_un_corpus_annote_est_refuse(self):
        corpus = [{"id": 0, "text": "NIR", "entities": [{"type": "nir"}]}]
        r = self.lance(corpus, [{"id": 0, "e": []}])
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("pas un témoin", r.stderr + r.stdout)

    def test_longueurs_differentes_refusees(self):
        r = self.lance([{"id": 0, "text": "x", "entities": []}], [])
        self.assertNotEqual(r.returncode, 0)


if __name__ == "__main__":
    unittest.main()
