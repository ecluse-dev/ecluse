"""Tests de l'annotation des IBAN à clé invalide du corpus v3 (22/11/2026).

Décision du mainteneur (DECISIONS.md, 22 novembre, point 7) : un IBAN mal
recopié reste le compte de quelqu'un ; le corpus l'annote donc `iban`. On
vérifie ici trois choses : l'annotation couvre exactement l'IBAN de la phrase
piège, sa clé est bien fausse (c'est toujours un piège pour la validation
structurelle), et le texte généré n'a pas changé (même tirage qu'avant).
"""

import hashlib
import random
import re
import unittest

import generate_corpus as g

PHRASE = re.compile(r"L'IBAN (.+?) a été refusé par la banque \(clé invalide\)\.")


def cle_iban_valide(iban: str) -> bool:
    compact = re.sub(r"\s", "", iban)
    tourne = compact[4:] + compact[:4]
    chiffres = "".join(str(int(c, 36)) for c in tourne)
    return int(chiffres) % 97 == 1


def corpus(n: int):
    rng = random.Random(42)
    return [g.build_doc(i, rng) for i in range(n)]


class IbanPiegeAnnote(unittest.TestCase):
    def setUp(self):
        self.docs = corpus(1000)

    def test_chaque_iban_piege_est_annote_iban_a_sa_position(self):
        vus = 0
        for d in self.docs:
            m = PHRASE.search(d["text"])
            if not m:
                continue
            vus += 1
            attendu = {"type": "iban", "start": m.start(1), "end": m.end(1)}
            self.assertIn(attendu, d["entities"], d["text"])
        self.assertEqual(vus, 48)

    def test_la_cle_de_l_iban_piege_reste_fausse(self):
        for d in self.docs:
            m = PHRASE.search(d["text"])
            if m:
                self.assertFalse(cle_iban_valide(m.group(1)), m.group(1))

    def test_totaux_v3_1000_documents(self):
        types = [e["type"] for d in self.docs for e in d["entities"]]
        # 871 identifiants structurels + 72 `siren` (P2-261, 23/11/2026).
        self.assertEqual(len([t for t in types if t != "siren"]), 871)
        self.assertEqual(types.count("siren"), 72)
        self.assertEqual(types.count("iban"), 262)

    def test_texte_inchange_par_l_annotation(self):
        # Empreinte des 1 000 textes (graine 42) avant l'ajout de l'annotation,
        # calculée le 22/11/2026 sur `main` (94749ac) : l'annotation ne doit
        # consommer aucun tirage.
        h = hashlib.sha256()
        for d in self.docs:
            h.update(d["text"].encode("utf-8"))
            h.update(b"\n")
        self.assertEqual(h.hexdigest(), EMPREINTE_TEXTES)


EMPREINTE_TEXTES = "7405d819103404f453961c77fcbfbd695925d2763d61b06b30db30f0de849516"

if __name__ == "__main__":
    unittest.main()
