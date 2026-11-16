#!/usr/bin/env python3
"""Tests du balayage « commune à mot de voie » et de son scoreur (P2-213) :
`python3 -m unittest discover -s bench`. Données synthétiques ; les noms de
communes viennent du référentiel public versionné."""

import os
import re
import tempfile
import unittest

import generate_corpus_cedex as gc
import generate_corpus_commune_voie as gv
import score_commune_voie as sv

ICI = os.path.dirname(os.path.abspath(__file__))
COMMUNES = os.path.join(ICI, "..", "packages", "ecluse_reference", "assets",
                        "geo_communes.csv.gz")
DETECTEUR = os.path.join(ICI, "..", "packages", "ecluse_redact", "lib", "src",
                         "heuristics", "adresse_detector.dart")


class Lecture(unittest.TestCase):
    def test_lit_les_types_de_voie_du_detecteur(self):
        voies = gv.lit_voies(DETECTEUR)
        for attendu in ("RUE", "CHEMIN", "CHAUSSEE", "ALLEE", "COURS"):
            self.assertIn(attendu, voies)
        self.assertTrue(all(v == v.upper() and v.isascii() for v in voies))

    def test_refuse_un_fichier_sans_la_liste_ou_une_liste_vide(self):
        for contenu in ("const x = 1;\n", "static const _voies = [\n];\n"):
            f = tempfile.NamedTemporaryFile("w", suffix=".dart", delete=False,
                                            encoding="utf-8")
            f.write(contenu)
            f.close()
            try:
                with self.assertRaises(ValueError):
                    gv.lit_voies(f.name)
            finally:
                os.unlink(f.name)

    def test_selection_des_communes(self):
        par_mots = {2: [("1", "52", "GRAFFIGNY CHEMIN", "Graffigny-Chemin"),
                        ("2", "25", "ROCHE LEZ", "Roche-lez")],
                    1: [("3", "80", "RUE", "Rue"), ("4", "70", "VESOUL",
                                                    "Vesoul")]}
        trouvees = gv.communes_a_mot_de_voie(par_mots, {"CHEMIN", "RUE"})
        self.assertEqual([(c[0], c[4]) for c in trouvees],
                         [("3", "RUE"), ("1", "CHEMIN")])


class Corpus(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.par_mots = gc.lit_communes(COMMUNES)
        cls.voies = gv.lit_voies(DETECTEUR)
        cls.docs = gv.construit(cls.par_mots, cls.voies, 42)

    def test_reproductible_a_graine_egale(self):
        self.assertEqual(self.docs, gv.construit(self.par_mots, self.voies, 42))
        self.assertNotEqual(self.docs,
                            gv.construit(self.par_mots, self.voies, 43))

    def test_toutes_les_cases_pour_chaque_commune(self):
        communes = {d["com"] for d in self.docs}
        self.assertGreaterEqual(len(communes), 40)
        self.assertEqual(len(self.docs), len(communes) * 6 * 2 * 3 * 2)
        self.assertEqual({(d["ecriture"], d["casse"]) for d in self.docs},
                         set(gv.CASES))

    def test_le_nom_contient_un_mot_de_voie(self):
        for d in self.docs:
            debut, fin = d["parties"]["commune"]
            nom = gv.sans_accent(d["text"][debut:fin]).upper()
            self.assertIn(d["mot_de_voie"], re.split(r"[ '’-]", nom))

    def test_positions_et_annotations(self):
        for d in self.docs:
            t = d["text"]
            cp = d["parties"]["cp"]
            self.assertRegex(t[cp[0]:cp[1]], r"^\d{5}$")
            e = d["entities"][0]
            self.assertEqual(e["end"] > d["parties"]["commune"][1],
                             d["cedex"] == "avec")
            if d["voie"] == "avec":
                self.assertEqual(e["start"], d["parties"]["voie"][0])
                self.assertRegex(t[slice(*d["parties"]["voie"])], r"^\d+ ")
            else:
                self.assertEqual(e["start"], cp[0])
                self.assertIsNone(d["parties"]["voie"])
            self.assertEqual(len(d["entities"]),
                             2 if d["suite"] == "adresse" else 1)
            if d["suite"] == "adresse":
                self.assertRegex(t[slice(*d["parties"]["seconde"])],
                                 r"^\d{5} \S+$")
            if d["suite"] == "mot":
                self.assertRegex(t[slice(*d["parties"]["ligne_mot"])],
                                 r"(?i)^\d{5} \w+ en attente$")
            if d["casse"] == "capitales":
                self.assertEqual(t, t.upper())
            else:
                self.assertTrue(t.startswith("Courrier à adresser à :\n"))


class Scoreur(unittest.TestCase):
    def setUp(self):
        self.texte = ("Courrier :\n52417 GRAFFIGNY CHEMIN CEDEX 7\n"
                      "39314 Colis en attente\nMerci.")
        self.doc = {
            "id": 0, "text": self.texte,
            "entities": [{"type": "adresse", "start": 11, "end": 41}],
            "parties": {"voie": None, "seconde": None, "cp": [11, 16],
                        "commune": [17, 33], "ligne_mot": [42, 64]},
            "com": "1", "mot_de_voie": "CHEMIN", "ecriture": "postale",
            "casse": "ordinaire", "cedex": "avec", "suite": "mot",
            "voie": "sans"}

    def test_le_defaut_de_depart_debut_en_clair(self):
        # « 52417 GRAFFIGNY [ADRESSE] » : la voie lue à partir de « CHEMIN ».
        pred = {"entities": [{"type": "adresse", "start": 27, "end": 53}]}
        defaut, clair, masquee = sv.juge(self.doc, pred)
        self.assertTrue(defaut)
        self.assertEqual(clair, {"cp", "commune", "debut"})
        self.assertTrue(masquee)

    def test_tout_couvert(self):
        pred = {"entities": [{"type": "adresse", "start": 11, "end": 41}]}
        self.assertEqual(sv.juge(self.doc, pred), (False, set(), False))

    def test_fin_du_nom_seule_en_clair(self):
        pred = {"entities": [{"type": "adresse", "start": 11, "end": 26}]}
        defaut, clair, _ = sv.juge(self.doc, pred)
        self.assertTrue(defaut)
        self.assertEqual(clair, {"commune"})

    def test_comptes_refus_et_prediction_absente(self):
        autre = dict(self.doc, id=1)
        preds = {0: {"entities": [{"type": "adresse", "start": 27,
                                   "end": 53}]},
                 1: {"entities": [], "refuse": True}}
        t, par_axe, par_mot, parties = sv.compte([self.doc, autre], preds)
        self.assertEqual((t["documents"], t["defaut"], t["refus"],
                          t["debut"], t["fin_seule"]), (2, 1, 1, 1, 0))
        self.assertEqual(par_mot["CHEMIN"], [1, 1])
        self.assertEqual(par_axe[("suite", "mot")], [1, 1])
        self.assertEqual((t["lignes_mot"], t["lignes_mot_masquees"]), (1, 1))
        with self.assertRaises(ValueError) as refus:
            sv.compte([self.doc], {})
        self.assertNotIn("GRAFFIGNY", str(refus.exception))


if __name__ == "__main__":
    unittest.main()
