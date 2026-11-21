#!/usr/bin/env python3
"""Tests de la mesure préalable de P2-250 : données synthétiques, aucun fichier
du dépôt lu. `python3 -m unittest discover -s bench`."""

import gzip
import json
import os
import tempfile
import unittest

import mesure_patronymes_referentiel as m


class TestMesure(unittest.TestCase):
    def test_norm_et_patronyme(self):
        self.assertEqual(m.norm("Lefèvre"), "LEFEVRE")
        self.assertEqual(m.patronyme("M. Julien Chevrier"), "CHEVRIER")
        self.assertEqual(m.patronyme("Mme Anne de la Roche"), "ROCHE")
        self.assertEqual(m.patronyme("Dr"), None)

    def test_charge_referentiel_ignore_l_entete(self):
        with tempfile.TemporaryDirectory() as d:
            chemin = os.path.join(d, "r.tsv.gz")
            with gzip.open(chemin, "wt", encoding="utf-8") as f:
                f.write("# Source : synthétique\nDURAND\t500\nROCHE\t40\n")
            self.assertEqual(m.charge_referentiel(chemin),
                             {"DURAND": 500, "ROCHE": 40})

    def test_couverture_par_seuil_et_noms_composes(self):
        ref = {"DURAND": 500, "ROCHE": 40}
        with tempfile.TemporaryDirectory() as d:
            c = os.path.join(d, "c.jsonl")
            texte = "M. Paul Durand-Roche et Mme Zora Inconnu."
            ents = [{"type": "nom", "start": 3, "end": 20},
                    {"type": "nom", "start": 28, "end": 40},
                    {"type": "adresse", "start": 0, "end": 2}]
            with open(c, "w", encoding="utf-8") as f:
                f.write(json.dumps({"text": texte, "entities": ents}) + "\n")
            noms, absents = m.couverture([c], ref)
        self.assertEqual(noms, {"DURAND", "ROCHE", "INCONNU"})
        self.assertEqual(absents[30], ["INCONNU"])
        self.assertEqual(absents[100], ["INCONNU", "ROCHE"])

    def test_contamination_triee_par_effectif(self):
        r = m.contamination(["porte", "rare", "marche"],
                            {"PORTE": 9000, "MARCHE": 3000})
        self.assertEqual(r[30], ["porte", "marche"])
        self.assertEqual(r[3000], ["porte", "marche"])


if __name__ == "__main__":
    unittest.main()
