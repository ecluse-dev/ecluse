#!/usr/bin/env python3
"""Tests du generateur et du scoreur de QI : `python3 -m unittest discover -s
bench` (depuis la racine). Donnees synthetiques, aucune lecture reseau."""

import csv
import gzip
import os
import re
import unittest

import generate_corpus_qi as gen
import score_qi

ASSET = os.path.join(os.path.dirname(__file__), "..", "packages",
                     "ecluse_reference", "assets", "geo_communes.csv.gz")
TYPES_ATTENDUS = {"profession", "lieu", "age"}


def corpus(nom, n=300, seed=42):
    return gen.construit(nom, n, seed)


def ent(t, s, e):
    return {"type": t, "start": s, "end": e}


class GenerateurTest(unittest.TestCase):
    def test_reproductible_par_graine(self):
        for nom, _ in gen.FABRIQUES:
            self.assertEqual(corpus(nom, 50, 7), corpus(nom, 50, 7))

    def test_graines_differentes_donnent_des_corpus_differents(self):
        self.assertNotEqual(corpus("realiste", 50, 1), corpus("realiste", 50, 2))

    def test_ajouter_des_documents_ne_decale_pas_le_debut(self):
        # Un RNG par corpus : les 50 premiers documents sont identiques.
        self.assertEqual(corpus("adversarial", 50), corpus("adversarial", 80)[:50])

    def test_offsets_exacts_et_types_connus(self):
        for nom, _ in gen.FABRIQUES:
            for d in corpus(nom):
                for e in d["entities"]:
                    self.assertIn(e["type"], TYPES_ATTENDUS)
                    mention = d["text"][e["start"]:e["end"]]
                    self.assertTrue(mention.strip(), (nom, d["id"]))
                    self.assertEqual(mention, mention.strip())

    def test_aucun_chevauchement_dans_un_document(self):
        for nom, _ in gen.FABRIQUES:
            for d in corpus(nom):
                es = sorted(d["entities"], key=lambda e: e["start"])
                for a, b in zip(es, es[1:]):
                    self.assertLessEqual(a["end"], b["start"], (nom, d["id"]))

    def test_les_ages_ont_la_forme_convenue(self):
        for nom in ("realiste", "adversarial"):
            for d in corpus(nom):
                for e in d["entities"]:
                    if e["type"] != "age":
                        continue
                    m = d["text"][e["start"]:e["end"]]
                    self.assertTrue(re.search(r"[  ]ans$", m), m)

    def test_temoin_sans_aucun_qi_ni_personne(self):
        for d in corpus("temoin"):
            self.assertEqual(d["entities"], [])
            self.assertEqual(d["personnes"], 0)

    def test_realiste_une_seule_personne(self):
        self.assertTrue(all(d["personnes"] == 1 for d in corpus("realiste")))

    def test_adversarial_couvre_les_pieges(self):
        docs = corpus("adversarial", 400)
        texte = "\n".join(d["text"] for d in docs)
        self.assertTrue(any(d["personnes"] >= 2 for d in docs))
        for mot in gen.COMMUNES_HOMONYMES[:3]:
            self.assertIn(mot, texte)
        for mot in ("Paris", "Mamoudzou", "Bezonvaux"):
            self.assertIn(mot, texte)
        self.assertIn(" ans", texte)  # espace insecable
        self.assertTrue(any(f"{w} ans" in texte
                            for w in gen.AGES_TOUTES_LETTRES))
        # Au moins un document a deux lieux et au moins un a deux ages.
        def n(d, t):
            return sum(1 for e in d["entities"] if e["type"] == t)
        self.assertTrue(any(n(d, "lieu") >= 2 for d in docs))
        self.assertTrue(any(n(d, "age") >= 2 for d in docs))
        # Au moins un document avec une profession mais sans lieu.
        self.assertTrue(any(n(d, "profession") and not n(d, "lieu")
                            for d in docs))

    def test_professions_hors_perimetre_jamais_annotees(self):
        for nom, _ in gen.FABRIQUES:
            for d in corpus(nom):
                for e in d["entities"]:
                    if e["type"] != "profession":
                        continue
                    mention = d["text"][e["start"]:e["end"]]
                    for hors in gen.HORS_PERIMETRE:
                        self.assertNotIn(hors.split()[-1], mention)

    def test_aucune_donnee_d_identification(self):
        # Regle 1 : donnees synthetiques. Aucun long nombre, aucun email.
        for nom, _ in gen.FABRIQUES:
            for d in corpus(nom):
                self.assertIsNone(re.search(r"\d{5,}", d["text"]), d["text"])
                self.assertNotIn("@", d["text"])

    @unittest.skipUnless(os.path.exists(ASSET), "asset de reference absent")
    def test_les_communes_utilisees_existent_dans_l_asset(self):
        with gzip.open(ASSET, "rt", encoding="utf-8") as f:
            connues = {r["LIBELLE"] for r in csv.DictReader(f, delimiter=";")}
        manquantes = [c for c in gen.TOUTES_COMMUNES if c not in connues]
        self.assertEqual(manquantes, [])


class ScoreurTest(unittest.TestCase):
    def setUp(self):
        self.docs = {d["id"]: d for d in corpus("adversarial", 120)}

    def preds(self, f):
        return {i: {"entities": f(d)} for i, d in self.docs.items()}

    def test_predictions_parfaites(self):
        s = score_qi.score(self.docs, self.preds(lambda d: d["entities"]))
        for t, l in s["types"].items():
            if l["annotes"]:
                self.assertEqual(l["strict"]["rappel"], 1.0)
                self.assertEqual(l["strict"]["precision"], 1.0)
                self.assertEqual(l["non_couverts"], 0.0)

    def test_predictions_vides(self):
        s = score_qi.score(self.docs, self.preds(lambda d: []))
        for l in s["types"].values():
            if l["annotes"]:
                self.assertEqual(l["strict"]["rappel"], 0.0)
                self.assertEqual(l["non_couverts"], 1.0)
        self.assertEqual(s["detections"], 0)

    def test_souple_indulgent_mais_non_couverts_le_montre(self):
        gold = {0: {"id": 0, "entities": [ent("lieu", 10, 20)],
                    "personnes": 1}}
        pred = {0: {"entities": [ent("lieu", 19, 20)]}}
        s = score_qi.score(gold, pred)
        lieu = s["types"]["lieu"]
        self.assertEqual(lieu["souple"]["tp"], 1)   # 1 caractere suffit
        self.assertEqual(lieu["strict"]["tp"], 0)
        self.assertAlmostEqual(lieu["non_couverts"], 0.9)

    def test_mauvais_type_ne_compte_pas(self):
        gold = {0: {"id": 0, "entities": [ent("lieu", 0, 5)], "personnes": 1}}
        pred = {0: {"entities": [ent("age", 0, 5)]}}
        s = score_qi.score(gold, pred)
        self.assertEqual(s["types"]["lieu"]["strict"]["tp"], 0)
        self.assertEqual(s["types"]["lieu"]["strict"]["fn"], 1)
        self.assertEqual(s["types"]["age"]["strict"]["fp"], 1)
        self.assertEqual(s["types"]["lieu"]["non_couverts"], 1.0)

    def test_une_prediction_ne_sert_qu_une_fois(self):
        gold = {0: {"id": 0, "entities": [ent("lieu", 0, 5), ent("lieu", 3, 8)],
                    "personnes": 1}}
        pred = {0: {"entities": [ent("lieu", 0, 8)]}}
        s = score_qi.score(gold, pred)
        self.assertEqual(s["types"]["lieu"]["souple"]["tp"], 1)
        self.assertEqual(s["types"]["lieu"]["souple"]["fn"], 1)

    def test_temoin_toute_extraction_est_un_faux_positif(self):
        temoin = {d["id"]: d for d in corpus("temoin", 30)}
        pred = {i: {"entities": [ent("lieu", 0, 3)] if i < 5 else []}
                for i in temoin}
        s = score_qi.score(temoin, pred)
        self.assertEqual(s["detections"], 5)
        self.assertEqual(s["documents_avec_detection"], 5)
        self.assertEqual(s["types"]["lieu"]["strict"]["fp"], 5)

    def test_statuts_rapportes_s_ils_existent(self):
        pred = {i: {"entities": [], "statut": "aucun_qi" if i % 2 else "evalue"}
                for i in self.docs}
        s = score_qi.score(self.docs, pred)
        self.assertEqual(sum(s["statuts"].values()), len(self.docs))
        self.assertIsNone(score_qi.score(self.docs, self.preds(lambda d: []))
                          ["statuts"])

    def test_rappel_par_nombre_de_personnes(self):
        s = score_qi.score(self.docs, self.preds(lambda d: d["entities"]))
        self.assertEqual(s["par_groupe"]["plusieurs personnes"]
                         ["rappel_strict"], 1.0)
        self.assertGreater(s["par_groupe"]["plusieurs personnes"]
                           ["documents"], 0)


if __name__ == "__main__":
    unittest.main()
