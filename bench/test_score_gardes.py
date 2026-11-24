"""P2-278 : `score_gardes.py --lignes` imprime une ligne lisible par clé (suivie
par le tableau de bord), sans aucune valeur du texte. Corpus synthétique."""
import json
import os
import subprocess
import sys
import tempfile
import unittest

ICI = os.path.dirname(os.path.abspath(__file__))


class LignesTest(unittest.TestCase):
    def lance(self, corpus, pred):
        with tempfile.TemporaryDirectory() as d:
            c, p = os.path.join(d, "c.jsonl"), os.path.join(d, "p.jsonl")
            for chemin, docs in ((c, corpus), (p, pred)):
                with open(chemin, "w", encoding="utf-8") as f:
                    for x in docs:
                        f.write(json.dumps(x) + "\n")
            r = subprocess.run(
                [sys.executable, os.path.join(ICI, "score_gardes.py"),
                 "--corpus", c, "--pred", p, "--par", "famille,ecriture",
                 "--lignes"], capture_output=True, text=True, check=True)
        return r.stdout.splitlines()

    def test_une_ligne_par_cle_et_un_total(self):
        texte = "Adresse 69003 Lyon 3e ici."
        corpus = [
            {"id": 0, "text": texte, "famille": "adresse_cp_commune",
             "ecriture": "Lyon 3e",
             "entities": [{"type": "adresse", "start": 8, "end": 21}]},
            {"id": 1, "text": texte, "famille": "adresse_cp_commune",
             "ecriture": "Lyon 3e",
             "entities": [{"type": "adresse", "start": 8, "end": 21}]},
        ]
        pred = [{"id": 0, "entities": [{"type": "adresse", "start": 8, "end": 21}]},
                {"id": 1, "entities": [{"type": "adresse", "start": 8, "end": 18}]}]
        lignes = self.lance(corpus, pred)
        self.assertEqual(lignes, [
            "sonde adresse cle_non_calculable adresse_cp_commune/Lyon 3e : "
            "couverts 1/2",
            "sonde TOTAL : couverts 1/2",
        ])
        self.assertTrue(all("69003" not in l for l in lignes))


if __name__ == "__main__":
    unittest.main()
