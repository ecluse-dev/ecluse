#!/usr/bin/env python3
"""Tests du corpus de pathologies (P2-112) :
`python3 -m unittest discover -s bench` (depuis la racine)."""

import unittest

import generate_corpus_pathologies as g


# SHA-256 des corpus d'origine (graine 42, n = 300), relevees avant P2-129.
EMPREINTES = {
    "indices": "85097494274fd6ad1c4b8e6e1123c45ea8ac1603b40e8750a4d4f3c8702daa9b",
    "temoin": "f8fefa8bf3479bdc31e2245fb2602e1f3adb20c646109096f60cf7253f78b646",
    "variantes": "bedb38622af8c2fee47c9f9305ca94be893195d609df23eead659bad8c79158c",
}


class CorpusPathologiesTest(unittest.TestCase):
    def test_offsets_exacts(self):
        for d in g.construit("indices", 200, 42):
            self.assertTrue(d["pathologies"])
            for p in d["pathologies"]:
                self.assertEqual(d["text"][p["start"]:p["end"]], p["mention"])

    def test_mentions_tirees_de_la_table(self):
        connues = {m for _, _, m in g.ENTREES}
        for d in g.construit("indices", 200, 42):
            for p in d["pathologies"]:
                self.assertIn(p["mention"], connues)
                self.assertTrue(p["categorie"] and p["systeme"])

    def test_temoin_sans_annotation(self):
        for d in g.construit("temoin", 200, 42):
            self.assertEqual(d["pathologies"], [])

    def test_reproductible_et_prefixe_stable(self):
        self.assertEqual(g.construit("indices", 50, 42),
                         g.construit("indices", 50, 42))
        self.assertEqual(g.construit("indices", 100, 42)[:50],
                         g.construit("indices", 50, 42))
        self.assertNotEqual(g.construit("indices", 50, 42),
                            g.construit("indices", 50, 7))


class VariantesTest(unittest.TestCase):
    def test_une_forme_adjectivale_annotee_par_document(self):
        formes = {f for m, fe, _ in g.ADJECTIFS for f in (m, fe)}
        for d in g.construit("variantes", 200, 42):
            self.assertEqual(len(d["pathologies"]), 1)
            p = d["pathologies"][0]
            self.assertEqual(d["text"][p["start"]:p["end"]], p["mention"])
            self.assertIn(p["mention"], formes)

    def test_negations_presentes_non_annotees(self):
        docs = g.construit("variantes", 200, 42)
        avec = [d for d in docs if any(m in d["text"]
                                      for m in g.NEGATIONS_MENTIONS)]
        self.assertGreater(len(avec), 100)


class FormesLibresTest(unittest.TestCase):
    def test_offsets_et_une_forme_par_document(self):
        docs = g.construit("formes_libres", 300, 42)
        formes = {d["forme"] for d in docs}
        self.assertEqual(formes, set(g.FORMES_LIBRES))
        for d in docs:
            for p in d["pathologies"]:
                self.assertEqual(d["text"][p["start"]:p["end"]], p["mention"])

    def test_negations_et_suspicions_non_annotees(self):
        annotees = set(g.FORMES_LIBRES_ANNOTEES)
        for d in g.construit("formes_libres", 300, 42):
            attendu = 1 if d["forme"] in annotees else 0
            self.assertEqual(len(d["pathologies"]), attendu, d["text"])

    def test_prefixe_stable_et_graine(self):
        self.assertEqual(g.construit("formes_libres", 100, 42)[:50],
                         g.construit("formes_libres", 50, 42))
        self.assertNotEqual(g.construit("formes_libres", 50, 42),
                            g.construit("formes_libres", 50, 7))

    def test_corpus_existants_inchanges(self):
        # Empreintes relevees AVANT l'ajout du corpus (graine 42, n = 300).
        import hashlib, json
        for nom, empreinte in EMPREINTES.items():
            h = hashlib.sha256()
            for d in g.construit(nom, 300, 42):
                h.update((json.dumps(d, ensure_ascii=False) + "\n").encode())
            self.assertEqual(h.hexdigest(), empreinte, nom)


if __name__ == "__main__":
    unittest.main()
