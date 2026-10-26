#!/usr/bin/env python3
"""Tests du generateur et du scoreur du patronyme seul : `python3 -m unittest
discover -s bench`. Donnees synthetiques, aucune lecture reseau."""

import unittest

import generate_corpus_patronymes as gen
import score_patronymes as sp

CAS = {"a": {"ancre", "a"}, "b": {"b_debut", "b_milieu"},
       "c": {"ancre", "c_debut", "c_milieu"}, "leurres": {"ancre"}}


def corpus(nom, n=200, seed=42):
    return gen.construit(nom, n, seed)


def par_id(docs):
    return {d["id"]: d for d in docs}


def preds_parfaits(docs):
    """Predictions indexees par identifiant de document."""
    return {d["id"]: {"mentions": [dict(e) for e in d["entities"]]}
            for d in docs}


class GenerateurTest(unittest.TestCase):
    def test_reproductible_par_graine(self):
        for nom, _ in gen.FABRIQUES:
            self.assertEqual(corpus(nom, 60, 7), corpus(nom, 60, 7))
        self.assertNotEqual(corpus("b", 60, 1), corpus("b", 60, 2))

    def test_offsets_exacts_et_cas_attendus(self):
        for nom, _ in gen.FABRIQUES:
            for d in corpus(nom):
                for e in d["entities"]:
                    self.assertIn(e["cas"], CAS[nom])
                    m = d["text"][e["start"]:e["end"]]
                    self.assertTrue(m.strip() and m == m.strip())

    def test_cas_a_ancre_puis_patronyme_dans_le_meme_document(self):
        for d in corpus("a"):
            ancre, seul = d["entities"]
            self.assertEqual((ancre["cas"], seul["cas"]), ("ancre", "a"))
            nom = d["text"][ancre["start"]:ancre["end"]].split()[-1]
            self.assertEqual(d["text"][seul["start"]:seul["end"]], nom)

    def test_cas_b_sans_ancrage(self):
        for d in corpus("b"):
            self.assertEqual(len(d["entities"]), 1)
            self.assertEqual(d["rang"], 0)

    def test_cas_c_ancre_au_rang_0_seulement(self):
        for d in corpus("c"):
            cas = [e["cas"] for e in d["entities"]]
            self.assertEqual(cas, ["ancre"] if d["rang"] == 0
                             else [cas[0]])
            if d["rang"] > 0:
                self.assertTrue(cas[0].startswith("c_"))

    def test_leurres_sans_entite_apres_l_ancre(self):
        for d in corpus("leurres"):
            self.assertEqual(bool(d["entities"]), d["rang"] == 0)

    def test_leurre_contient_le_mot_courant_du_patronyme(self):
        par_dossier = {}
        for d in corpus("leurres"):
            par_dossier.setdefault(d["dossier"], []).append(d)
        for docs in par_dossier.values():
            e = docs[0]["entities"][0]
            nom = docs[0]["text"][e["start"]:e["end"]].split()[-1]
            for d in docs[1:]:
                self.assertIn(nom, d["text"])

    def test_rose_exclu_des_leurres(self):
        self.assertNotIn("Rose", gen.LEURRES)


class ScoreurTest(unittest.TestCase):
    def test_detection_parfaite(self):
        docs = corpus("c", 60)
        par_cas, leurres = sp.mesure(par_id(docs), preds_parfaits(docs))
        for a, b in par_cas.values():
            self.assertEqual(a, b)
        self.assertEqual(leurres, (0, 0))

    def test_aucune_detection(self):
        docs = corpus("b", 60)
        par_cas, _ = sp.mesure(par_id(docs), {})
        self.assertTrue(all(a == 0 and b > 0 for a, b in par_cas.values()))

    def test_leurre_detecte_est_un_faux_positif(self):
        docs = [{"id": 0, "dossier": 0, "rang": 1, "text": "Petit déjeuner",
                 "entities": []}]
        preds = {0: {"mentions": [{"type": "nom", "start": 0, "end": 5,
                                   "jeton": "[NOM_1]"}]}}
        self.assertEqual(sp.mesure(par_id(docs), preds)[1], (1, 1))
        self.assertEqual(sp.mesure(par_id(docs), {})[1], (0, 1))

    def test_detection_d_un_autre_type_ne_compte_pas(self):
        docs = [{"id": 0, "dossier": 0, "rang": 0, "text": "Verdier",
                 "entities": [{"type": "nom", "start": 0, "end": 7,
                               "identite": "p1", "cas": "b_debut"}]}]
        preds = {0: {"mentions": [{"type": "email", "start": 0, "end": 7,
                                   "jeton": "[EMAIL_1]"}]}}
        self.assertEqual(sp.mesure(par_id(docs), preds)[0]["b_debut"], (0, 1))

    def test_format_entities_accepte(self):
        docs = [{"id": 0, "dossier": 0, "rang": 0, "text": "Verdier",
                 "entities": [{"type": "nom", "start": 0, "end": 7,
                               "identite": "p1", "cas": "b_debut"}]}]
        preds = {0: {"entities": [{"type": "nom", "start": 0, "end": 7}]}}
        self.assertEqual(sp.mesure(par_id(docs), preds)[0]["b_debut"], (1, 1))

    def test_faux_positifs_hors_annotation(self):
        docs = [{"id": 0, "dossier": 0, "rang": 0, "text": "Mme Sophie Verdier ou Petit",
                 "entities": [{"type": "nom", "start": 4, "end": 18,
                               "identite": "p1", "cas": "ancre"}]}]
        preds = {0: {"mentions": [
            {"type": "nom", "start": 4, "end": 18, "jeton": "[NOM_1]"},
            {"type": "nom", "start": 22, "end": 27, "jeton": "[NOM_2]"}]}}
        self.assertEqual(sp.detections_hors_annotation(par_id(docs), preds),
                         (1, 2))

    def test_regle_naive_ignore_debut_de_phrase_et_mots_detectes(self):
        docs = [
            {"id": 0, "text": "Rendez-vous à Thionville.", "entities": []},
            {"id": 1, "text": "Thionville est loin. Merci.", "entities": []},
            {"id": 2, "text": "Appeler Verdier demain.", "entities": []},
        ]
        preds = {2: {"mentions": [{"type": "nom", "start": 8, "end": 15,
                                   "jeton": "[NOM_1]"}]}}
        self.assertEqual(sp.mots_capitalises_isoles(par_id(docs), preds),
                         (1, 3))


if __name__ == "__main__":
    unittest.main()
