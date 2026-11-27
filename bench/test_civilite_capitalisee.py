"""Tests de `civilite_capitalisee.py` (P2-322) : sonde, classement, témoins."""

import json
import os
import tempfile
import unittest

import civilite_capitalisee as C


class SondeTest(unittest.TestCase):
    def test_sonde_est_reproductible_et_bien_formee(self):
        with tempfile.TemporaryDirectory() as d:
            a, b = os.path.join(d, "a.jsonl"), os.path.join(d, "b.jsonl")
            C.cmd_sonde(a, 5)
            C.cmd_sonde(b, 5)
            self.assertEqual(open(a, encoding="utf-8").read(), open(b, encoding="utf-8").read())
            docs = [json.loads(l) for l in open(a, encoding="utf-8")]
        self.assertTrue(docs)
        listes = {d["liste"] for d in docs}
        # treize listes signalées + le témoin hors liste
        self.assertEqual(len(listes), 14)
        for d in docs:
            mot = d["text"][d["patro_debut"]:d["patro_fin"]]
            self.assertEqual(mot, mot.lower())  # écrit en minuscules
            self.assertTrue(d["text"].startswith(d["civilite"] + " "))  # civilité capitalisée
            self.assertEqual(d["entities"][0]["start"], d["patro_debut"])


class ClassementTest(unittest.TestCase):
    DOC = {"id": 0, "patro_debut": 9, "patro_fin": 14}

    def test_masque(self):
        r = {"entities": [{"type": "nom", "start": 9, "end": 14}], "warnings": []}
        self.assertEqual(C.classe(self.DOC, r), "masque")

    def test_signale(self):
        r = {"entities": [], "warnings": [
            "mot pris pour un nom commun derrière un prénom, non masqué : à vérifier (1 occurrence)."]}
        self.assertEqual(C.classe(self.DOC, r), "signale")

    def test_silencieux(self):
        r = {"entities": [], "warnings": ["autre avertissement à vérifier"]}
        self.assertEqual(C.classe(self.DOC, r), "silencieux")

    def test_partiellement_masque_est_en_clair(self):
        r = {"entities": [{"type": "nom", "start": 9, "end": 12}], "warnings": []}
        self.assertEqual(C.classe(self.DOC, r), "silencieux")


class TemoinsTest(unittest.TestCase):
    def test_trouve_civilite_capitalisee_devant_homonyme_minuscule(self):
        with tempfile.TemporaryDirectory() as d:
            c = os.path.join(d, "c.jsonl")
            with open(c, "w", encoding="utf-8") as f:
                for i, t in enumerate([
                        "Madame fait un malaise.",      # homonyme (verbe + patronyme)
                        "Madame Fait un malaise.",      # capitalisé : hors périmètre
                        "madame fait un malaise.",      # civilité en minuscules : hors périmètre
                        "Le patient va bien."]):
                    f.write(json.dumps({"id": i, "text": t}) + "\n")
            out = os.path.join(d, "t.jsonl")
            C.cmd_temoins(out, [c])
            docs = [json.loads(l) for l in open(out, encoding="utf-8")]
            totaux = json.load(open(out + ".totaux", encoding="utf-8"))
        self.assertEqual(len(docs), 1)
        self.assertEqual(docs[0]["text"][docs[0]["patro_debut"]:docs[0]["patro_fin"]], "fait")
        self.assertEqual(totaux, {"c.jsonl": 4})


if __name__ == "__main__":
    unittest.main()
