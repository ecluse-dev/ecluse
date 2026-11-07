"""Tests de la correspondance et de la fusion de `ner_predict.py` (P2-89).

Sans transformers ni modèle : seules les fonctions pures sont testées.
"""

import unittest

from ner_predict import fusionner, type_corpus, vers_entites


class TypeCorpus(unittest.TestCase):
    def test_correspondance(self):
        self.assertEqual(type_corpus("NOM_PERSONNE"), "nom")
        self.assertEqual(type_corpus("B-PRENOM_PERSONNE"), "nom")
        self.assertEqual(type_corpus("VILLE"), "adresse")
        self.assertEqual(type_corpus("NOM_SOCIETE"), "etablissement")

    def test_date_naissance(self):
        self.assertEqual(type_corpus("DATE_NAISSANCE"), "date_naissance")

    def test_inconnu_garde(self):
        self.assertEqual(type_corpus("IBAN"), "IBAN")
        self.assertEqual(type_corpus("DATE"), "DATE")


class Fusion(unittest.TestCase):
    def test_nom_un_blanc(self):
        t = "Mme Odile Marchetti vient"
        s = fusionner([{"type": "nom", "start": 4, "end": 9},
                       {"type": "nom", "start": 10, "end": 19}], t)
        self.assertEqual(s, [{"type": "nom", "start": 4, "end": 19}])

    def test_nom_deux_blancs_non_fusionnes(self):
        t = "Odile  Marchetti"
        s = fusionner([{"type": "nom", "start": 0, "end": 5},
                       {"type": "nom", "start": 7, "end": 16}], t)
        self.assertEqual(len(s), 2)

    def test_adresse_virgule_saut(self):
        t = "12 rue des Lilas,\n25000 Besançon"
        s = fusionner([{"type": "adresse", "start": 0, "end": 2},
                       {"type": "adresse", "start": 3, "end": 16},
                       {"type": "adresse", "start": 18, "end": 23},
                       {"type": "adresse", "start": 24, "end": 32}], t)
        self.assertEqual(s, [{"type": "adresse", "start": 0, "end": 32}])

    def test_types_differents(self):
        t = "Odile Paris"
        s = fusionner([{"type": "nom", "start": 0, "end": 5},
                       {"type": "adresse", "start": 6, "end": 11}], t)
        self.assertEqual(len(s), 2)

    def test_mot_entre_non_fusionne(self):
        t = "Odile et Marchetti"
        s = fusionner([{"type": "nom", "start": 0, "end": 5},
                       {"type": "nom", "start": 9, "end": 18}], t)
        self.assertEqual(len(s), 2)


class VersEntites(unittest.TestCase):
    def test_blanc_initial_retire(self):
        t = "Vu Mme Odile Marchetti."
        sorties = [{"entity_group": "PRENOM_PERSONNE", "start": 6, "end": 12},
                   {"entity_group": "NOM_PERSONNE", "start": 12, "end": 22}]
        self.assertEqual(vers_entites(sorties, t),
                         [{"type": "nom", "start": 7, "end": 22}])

    def test_offsets_absents_ignores(self):
        self.assertEqual(vers_entites(
            [{"entity_group": "EMAIL", "start": None, "end": None}], "x"), [])


if __name__ == "__main__":
    unittest.main()
