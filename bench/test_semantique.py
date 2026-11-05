#!/usr/bin/env python3
"""Tests du generateur de fuites semantiques (P2-105) :
`python3 -m unittest discover -s bench` (depuis la racine). Donnees
synthetiques, aucune lecture reseau."""

import unittest

import generate_corpus_semantique as gen
import score_semantique as score


def corpus(nom, n=200, seed=42):
    return gen.construit(nom, n, seed)


class GenerateurSemantiqueTest(unittest.TestCase):
    def test_reproductible_par_graine(self):
        for nom, _ in gen.FABRIQUES:
            self.assertEqual(corpus(nom, 50, 7), corpus(nom, 50, 7))

    def test_graines_differentes(self):
        self.assertNotEqual(corpus("indices", 50, 1), corpus("indices", 50, 2))

    def test_ajouter_des_documents_ne_decale_pas_le_debut(self):
        for nom, _ in gen.FABRIQUES:
            self.assertEqual(corpus(nom, 50), corpus(nom, 80)[:50])

    def test_offsets_exacts_et_types_connus(self):
        for nom, _ in gen.FABRIQUES:
            for d in corpus(nom):
                for i in d["indices"]:
                    self.assertIn(i["type"], gen.TYPES)
                    extrait = d["text"][i["start"]:i["end"]]
                    self.assertTrue(extrait and extrait == extrait.strip(),
                                    (nom, d["id"], extrait))

    def test_chaque_document_indices_porte_un_indice(self):
        for d in corpus("indices"):
            self.assertGreaterEqual(len(d["indices"]), 1, d["text"])
            self.assertIsNone(d["injection"])

    def test_temoin_sans_indice_ni_injection(self):
        for d in corpus("temoin"):
            self.assertEqual(d["indices"], [])
            self.assertIsNone(d["injection"])

    def test_tous_les_types_presents(self):
        types = {i["type"] for d in corpus("indices", 300) for i in d["indices"]}
        self.assertEqual(types, set(gen.TYPES))

    def test_injection_reprend_indices_au_meme_rang(self):
        for a, b in zip(corpus("indices"), corpus("injection")):
            self.assertTrue(b["text"].startswith(a["text"]))
            self.assertEqual(a["indices"], b["indices"])
            inj = b["injection"]
            self.assertIsNotNone(inj)
            self.assertIn(b["text"][inj["start"]:inj["end"]], gen.INJECTIONS)
            self.assertGreaterEqual(inj["start"], len(a["text"]))

    def test_accord_en_genre(self):
        for nom, _ in gen.FABRIQUES:
            for d in corpus(nom, 300):
                if d["text"].split(". ", 1)[1].startswith("Mme "):
                    self.assertNotIn(" a été reçu ", d["text"])
                    self.assertNotIn("l'un des résidents", d["text"])


class ScoreurSemantiqueTest(unittest.TestCase):
    def setUp(self):
        self.ind = corpus("indices", 20)
        self.tem = corpus("temoin", 20)

    def parfait(self, docs):
        return [{"id": d["id"], "statut": "verifie",
                 "signalements": [{"start": i["start"], "end": i["end"]}
                                  for i in d["indices"]]} for d in docs]

    def test_verificateur_parfait(self):
        t, n, nv = score.taux_indices(self.ind, self.parfait(self.ind))
        self.assertEqual((t, nv), (n, 0))
        self.assertEqual(score.fausses_alertes(self.tem, self.parfait(self.tem)),
                         (0, 20, 0))

    def test_document_absent_compte_non_verifie_jamais_propre(self):
        t, n, nv = score.taux_indices(self.ind, [])
        self.assertEqual((t, nv), (0, 20))
        self.assertEqual(score.fausses_alertes(self.tem, []), (0, 20, 20))

    def test_un_caractere_de_recouvrement_suffit(self):
        d = self.ind[0]
        i = d["indices"][0]
        pred = [{"id": d["id"], "statut": "verifie",
                 "signalements": [{"start": i["end"] - 1, "end": i["end"] + 5}]}]
        t, _, _ = score.taux_indices([d], pred)
        self.assertGreaterEqual(t, 1)

    def test_signalement_sur_le_temoin_est_une_fausse_alerte(self):
        d = self.tem[0]
        pred = [{"id": d["id"], "statut": "verifie",
                 "signalements": [{"start": 0, "end": 4}]}]
        self.assertEqual(score.fausses_alertes([d], pred), (1, 1, 0))


if __name__ == "__main__":
    unittest.main()
