"""Tests de l'annotation des NIR à clé invalide du corpus v3 (23/11/2026).

Décision du mainteneur (DECISIONS.md, 23 novembre, point 1) : un NIR mal
recopié reste celui d'un patient ; le corpus l'annote donc `nir`. Comme pour
l'IBAN (test_generate_corpus_iban_piege.py) : l'annotation couvre exactement
le NIR de la phrase piège, sa clé est fausse, et le texte généré n'a pas
changé (même tirage qu'avant).
"""

import hashlib
import random
import re
import unittest

import generate_corpus as g

PHRASE = re.compile(
    r"Attention, saisie erronée hier : (.+?) a été rejeté par le contrôle\.")


def cle_nir_juste(nir: str) -> bool:
    compact = re.sub(r"\D", "", nir)
    return len(compact) == 15 and 97 - int(compact[:13]) % 97 == int(compact[13:])


def corpus(n: int):
    rng = random.Random(42)
    return [g.build_doc(i, rng) for i in range(n)]


class NirPiegeAnnote(unittest.TestCase):
    def setUp(self):
        self.docs = corpus(1000)

    def test_chaque_nir_piege_est_annote_nir_a_sa_position(self):
        vus = 0
        for d in self.docs:
            m = PHRASE.search(d["text"])
            if not m:
                continue
            vus += 1
            attendu = {"type": "nir", "start": m.start(1), "end": m.end(1)}
            self.assertIn(attendu, d["entities"], d["text"])
        self.assertEqual(vus, 45)

    def test_la_cle_du_nir_piege_reste_fausse(self):
        for d in self.docs:
            m = PHRASE.search(d["text"])
            if m:
                self.assertFalse(cle_nir_juste(m.group(1)), m.group(1))

    def test_totaux_v3_1000_documents(self):
        types = [e["type"] for d in self.docs for e in d["entities"]]
        # 871 identifiants structurels + 72 `siren` (P2-261, 23/11/2026).
        self.assertEqual(len([t for t in types if t != "siren"]), 871)
        self.assertEqual(types.count("siren"), 72)
        self.assertEqual(types.count("nir"), 314)

    def test_texte_inchange_par_l_annotation(self):
        h = hashlib.sha256()
        for d in self.docs:
            h.update(d["text"].encode("utf-8"))
            h.update(b"\n")
        self.assertEqual(h.hexdigest(), EMPREINTE_TEXTES)


# Même empreinte que test_generate_corpus_iban_piege.py : l'annotation des NIR
# ne consomme aucun tirage (texte identique octet pour octet).
EMPREINTE_TEXTES = "7405d819103404f453961c77fcbfbd695925d2763d61b06b30db30f0de849516"

if __name__ == "__main__":
    unittest.main()
