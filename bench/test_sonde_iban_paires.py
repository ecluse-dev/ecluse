"""Tests de la sonde élargie de l'IBAN en paires et de son scoreur (P2-293).
Données synthétiques."""

import re
import unittest

from generate_sonde_iban_paires import SEPARATEURS, construit, en_paires, reference
from mesure_gardes_iban_paires import P
from score_gardes_iban_paires import masque_iban, sonde
import random


class Generateur(unittest.TestCase):
    def setUp(self):
        self.docs = construit(6, 42)

    def test_reproductible(self):
        self.assertEqual(self.docs, construit(6, 42))
        self.assertNotEqual(self.docs, construit(6, 7))

    def test_effectifs(self):
        # 2 clés × 4 séparateurs × 2 corps + 4 × 2 références, 6 chacune
        self.assertEqual(len(self.docs), (16 + 8) * 6)

    def test_toutes_dans_la_forme_paires(self):
        for d in self.docs:
            self.assertIsNotNone(P.search(d["text"]), d["id"])

    def test_separateur_unique_et_annotation_exacte(self):
        for d in self.docs:
            m = P.search(d["text"])
            seps = set(re.findall(r"[ \-./]", m.group(0)))
            self.assertEqual(seps, {SEPARATEURS[d["sep"]]})
            if d["entities"]:
                e = d["entities"][0]
                self.assertEqual((e["start"], e["end"]), (m.start(), m.end()))
            else:
                self.assertEqual(d["famille"], "reference")

    def test_corps_ocr_a_au_moins_une_lettre(self):
        for d in self.docs:
            if d["corps"] == "ocr":
                m = P.search(d["text"])
                corps = re.sub(r"[ \-./]", "", m.group(0))[4:]
                self.assertRegex(corps, r"[A-Za-z]")

    def test_phrases(self):
        mots = re.compile(r"virement|bancaires", re.I)
        for d in self.docs:
            self.assertEqual(bool(mots.search(d["text"])), d["phrase"] == "motcle")

    def test_en_paires_forme(self):
        v = en_paires(reference(random.Random(1)), "-", "chiffres", random.Random(1))
        self.assertRegex(v, r"^FR(-\d\d){12}-\d$")


class Scoreur(unittest.TestCase):
    def test_masque_iban_en_entier(self):
        e = [{"type": "iban", "start": 5, "end": 40}]
        self.assertTrue(masque_iban(e, 5, 40))
        self.assertFalse(masque_iban(e, 4, 40))
        self.assertFalse(masque_iban([{"type": "telephone", "start": 0, "end": 99}], 5, 40))

    def test_sonde_associe_prediction(self):
        docs = construit(1, 42)
        pred = [{"id": d["id"], "entities": []} for d in docs]
        res = sonde(docs, pred)
        self.assertEqual(len(res), len(docs))
        self.assertFalse(any(masque for _, _, masque, _ in res))


if __name__ == "__main__":
    unittest.main()
