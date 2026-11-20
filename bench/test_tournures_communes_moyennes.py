#!/usr/bin/env python3
"""Tests du témoin des communes moyennes (P2-238) :
`python3 -m unittest discover -s bench`. Données synthétiques et référentiel
public versionné."""

import contextlib
import io
import unittest

import generate_corpus_tournures_communes_moyennes as g
import score_tournures_communes_moyennes as s


class Generateur(unittest.TestCase):
    def setUp(self):
        self.communes = g.lit_communes()
        self.docs = g.construit(42, self.communes)

    def test_au_moins_quarante_communes_vingt_par_tranche(self):
        tirage = g.tire(self.communes, 42)
        total = sum(len(v) for v in tirage.values())
        self.assertGreaterEqual(total, 40)
        for nom, lieux in tirage.items():
            self.assertEqual(len(lieux), g.TOUR, nom)
            self.assertEqual(len({c[0] for c in lieux}), g.TOUR, nom)

    def test_population_dans_la_tranche(self):
        bornes = {nom: (bas, haut) for nom, bas, haut in g.TRANCHES}
        for d in self.docs:
            bas, haut = bornes[d["tranche"]]
            self.assertTrue(bas <= d["pmun"] < haut)

    def test_chaque_commune_dans_chaque_tournure(self):
        self.assertEqual(len(self.docs), 60 * len(g.TOURNURES))
        cases = {(d["text"][d["lieu"]["start"]:d["lieu"]["end"]],
                  d["tournure"]) for d in self.docs}
        self.assertEqual(len(cases), len(self.docs))

    def test_offsets_et_aucune_entite_annotee(self):
        libelles = {c[1] for c in self.communes}
        for d in self.docs:
            self.assertEqual(d["entities"], [])
            self.assertIn(d["text"][d["lieu"]["start"]:d["lieu"]["end"]],
                          libelles)

    def test_reproductible_et_graine_explicite(self):
        self.assertEqual(self.docs, g.construit(42, self.communes))
        self.assertNotEqual(self.docs, g.construit(7, self.communes))

    def test_aucune_commune_sans_population_dans_le_fichier(self):
        # Paris (75056) n'a pas de population dans le fichier : jamais tiré.
        tires = {c[0] for lieux in g.tire(self.communes, 42).values()
                 for c in lieux}
        self.assertNotIn("75056", tires)
        self.assertNotIn("75056", {c[0] for c in self.communes})


class Scoreur(unittest.TestCase):
    def test_recouvrement_et_comptes(self):
        docs = g.construit(42, g.lit_communes())
        pred = []
        for d in docs:
            ents = []
            if d["tournure"] == "dossier de":
                ents = [{"type": "nom", "start": d["lieu"]["start"],
                         "end": d["lieu"]["end"]}]
            elif d["tournure"] == "entretien avec":  # hors du lieu
                ents = [{"type": "nom", "start": 0, "end": 3}]
            pred.append({"id": d["id"], "entities": ents})
        par = s.mesure(docs, pred)
        self.assertEqual(par[("total", "*")]["masques"], 60)
        self.assertEqual(par[("tournure", "dossier de")]["masques"], 60)
        self.assertEqual(par[("tournure", "entretien avec")]["masques"], 0)
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            s.affiche(docs, par)
        sortie = buf.getvalue()
        self.assertIn("60 lieux masqués à tort", sortie)
        self.assertIn("tranche=30-50k : 20 / 80", sortie)

    def test_refus_prediction_absente(self):
        docs = g.construit(42, g.lit_communes())
        with self.assertRaises(KeyError):
            s.mesure(docs, [])


if __name__ == "__main__":
    unittest.main()
