#!/usr/bin/env python3
"""Tests du témoin « nombre à cinq chiffres + mot neutre », mot par mot, et de
son scoreur (P2-211) : `python3 -m unittest discover -s bench`. Données
synthétiques."""

import collections
import os
import re
import tempfile
import unittest

import generate_corpus_mots_neutres as gm
import score_mots_neutres as sm

ICI = os.path.dirname(os.path.abspath(__file__))
MOTS_DART = os.path.join(ICI, "..", "packages", "ecluse_redact", "lib", "src",
                         "heuristics", "mots_neutres.dart")


def _fichier(contenu):
    f = tempfile.NamedTemporaryFile("w", suffix=".dart", delete=False,
                                    encoding="utf-8")
    f.write(contenu)
    f.close()
    return f.name


class LectureDeLaListe(unittest.TestCase):
    def test_lit_les_mots_du_fichier_dart_versionne(self):
        mots = gm.lit_mots(MOTS_DART)
        self.assertGreater(len(mots), 50)
        self.assertEqual(len(mots), len(set(mots)))
        for attendu in ("euros", "numéros", "salariés", "à", "le", "kcal"):
            self.assertIn(attendu, mots)

    def test_ignore_les_commentaires_et_garde_l_ordre(self):
        chemin = _fichier("/// 'pas un mot'\nconst Set<String> motsNeutres = "
                          "{\n 'euros', // 'commentaire'\n 'à', 'euros',\n};\n")
        try:
            self.assertEqual(gm.lit_mots(chemin), ["euros", "à"])
        finally:
            os.unlink(chemin)

    def test_refuse_un_fichier_sans_la_liste_ou_une_liste_vide(self):
        for contenu in ("const x = 1;\n",
                        "const Set<String> motsNeutres = {\n};\n"):
            chemin = _fichier(contenu)
            try:
                with self.assertRaises(ValueError):
                    gm.lit_mots(chemin)
            finally:
                os.unlink(chemin)


class Formes(unittest.TestCase):
    def test_sans_accent_seulement_si_la_forme_differe(self):
        self.assertEqual(gm.formes("euros"), [("accentuee", "euros")])
        self.assertEqual(gm.formes("numéros"),
                         [("accentuee", "numéros"), ("sans_accent", "numeros")])
        self.assertEqual(gm.formes("à"),
                         [("accentuee", "à"), ("sans_accent", "a")])


class Corpus(unittest.TestCase):
    MOTS = ["euros", "numéros", "le", "à"]

    @classmethod
    def setUpClass(cls):
        cls.docs = gm.construit(cls.MOTS, 400, 42)

    def test_reproductible_a_graine_egale(self):
        self.assertEqual(self.docs, gm.construit(self.MOTS, 400, 42))
        self.assertNotEqual(self.docs, gm.construit(self.MOTS, 400, 43))

    def test_quatre_cents_phrases_par_mot_a_parts_egales(self):
        par_case = collections.Counter(
            (d["mot"], d["forme"], d["casse"]) for d in self.docs)
        for mot in self.MOTS:
            cases = {k: v for k, v in par_case.items() if k[0] == mot}
            self.assertEqual(sum(cases.values()), 400, mot)
            self.assertEqual(len(set(cases.values())), 1, mot)
        self.assertEqual(par_case[("euros", "accentuee", "capitales")], 200)
        self.assertEqual(par_case[("numéros", "sans_accent", "capitales")], 100)
        self.assertNotIn(("euros", "sans_accent", "capitales"), par_case)

    def test_forme_nombre_a_cinq_chiffres_puis_mot(self):
        for d in self.docs:
            self.assertEqual(d["entities"], [])
            nombres = re.findall(r"\d+", d["text"])
            self.assertEqual(len(nombres), 1)
            self.assertEqual(len(nombres[0]), 5)
            attendu = d["ecriture"]
            if d["casse"] == "capitales":
                attendu = attendu.upper()
                self.assertEqual(d["text"], d["text"].upper())
            self.assertIn(f"{nombres[0]} {attendu}", d["text"])

    def test_la_forme_sans_accent_n_a_aucun_accent(self):
        for d in self.docs:
            if d["forme"] == "sans_accent":
                self.assertTrue(d["text"].isascii())

    def test_casse_ordinaire_mot_en_minuscules_et_deux_regimes(self):
        ordinaires = [d for d in self.docs if d["casse"] == "ordinaire"]
        self.assertEqual({d["majuscules"] for d in ordinaires},
                         {"phrase", "mixte"})
        for d in ordinaires:
            self.assertEqual(d["ecriture"], d["ecriture"].lower())
            majuscules = sum(1 for c in d["text"] if c.isupper())
            if d["majuscules"] == "phrase":
                self.assertLessEqual(majuscules, 1)
            else:
                self.assertGreaterEqual(majuscules, 2)

    def test_tous_les_axes_sont_couverts_et_ids_contigus(self):
        self.assertEqual({d["position"] for d in self.docs},
                         {"debut", "milieu"})
        self.assertEqual({d["suite"] for d in self.docs},
                         {"rien", "neutre", "nom"})
        self.assertEqual([d["id"] for d in self.docs],
                         list(range(len(self.docs))))

    def test_refuse_un_nombre_de_phrases_non_partageable(self):
        for n in (0, -4, 402):
            with self.assertRaises(ValueError):
                gm.construit(self.MOTS, n, 42)


class Scoreur(unittest.TestCase):
    def _doc(self, i, texte, mot="numéros", forme="sans_accent",
             casse="capitales"):
        return {"id": i, "text": texte, "entities": [], "mot": mot,
                "forme": forme, "ecriture": "numeros", "casse": casse,
                "position": "debut", "suite": "neutre",
                "majuscules": "capitales"}

    def test_nombre_sous_une_adresse(self):
        doc = self._doc(0, "39314 NUMEROS EN ATTENTE.")
        pred = {"entities": [{"type": "adresse", "start": 0, "end": 13}]}
        self.assertEqual(sm.juge(doc, pred), (True, False, {"adresse"}))

    def test_detection_a_cote_du_nombre_ne_compte_pas(self):
        doc = self._doc(0, "39314 NUMEROS EN ATTENTE.")
        pred = {"entities": [{"type": "adresse", "start": 6, "end": 13}]}
        self.assertEqual(sm.juge(doc, pred), (False, False, set()))

    def test_autre_type_compte_a_part(self):
        doc = self._doc(0, "39314 NUMEROS EN ATTENTE.")
        pred = {"entities": [{"type": "identifiant", "start": 2, "end": 5}]}
        self.assertEqual(sm.juge(doc, pred), (False, True, {"identifiant"}))

    def test_refuse_une_phrase_sans_nombre_ou_une_prediction_absente(self):
        with self.assertRaises(ValueError):
            sm.juge(self._doc(0, "NUMEROS EN ATTENTE."), {"entities": []})
        with self.assertRaises(ValueError):
            sm.compte([self._doc(0, "39314 NUMEROS.")], {})

    def test_les_refus_ne_citent_aucune_valeur_du_texte(self):
        try:
            sm.juge(self._doc(7, "NUMEROS EN ATTENTE."), {"entities": []})
        except ValueError as e:
            self.assertNotIn("NUMEROS", str(e))

    def test_compte_par_mot_forme_et_casse_et_ligne_imprimee(self):
        corpus = [
            self._doc(0, "39314 NUMEROS EN ATTENTE."),
            self._doc(1, "39315 NUMEROS EN ATTENTE."),
            self._doc(2, "39316 NUMÉROS EN ATTENTE.", forme="accentuee"),
            self._doc(3, "39317 numeros en attente.", casse="ordinaire"),
            self._doc(4, "39318 numéros en attente.", forme="accentuee",
                      casse="ordinaire"),
        ]
        preds = {i: {"entities": []} for i in range(5)}
        preds[0] = {"entities": [{"type": "adresse", "start": 0, "end": 13}]}
        t, par_mot, par_axe, types = sm.compte(corpus, preds)
        self.assertEqual((t["phrases"], t["adresse"], t["autre"]), (5, 1, 0))
        self.assertEqual(par_mot["numéros"][("sans_accent", "capitales")],
                         [2, 1])
        self.assertEqual(par_axe[("casse", "capitales")], [3, 1])
        self.assertEqual(
            sm.ligne_mot("numéros", par_mot["numéros"]),
            "  mot=numéros : capitales 0 / 1, ordinaire 0 / 1 ; sans accent : "
            "capitales 1 / 2, ordinaire 0 / 1")


if __name__ == "__main__":
    unittest.main()
