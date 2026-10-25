#!/usr/bin/env python3
"""Tests du decompte de fuite hors civilite : `python3 -m unittest discover -s
bench`. Cas construits a la main, donnees synthetiques."""

import unittest

import leak_hors_civilite as lc


def doc(texte, debut_fin):
    return {1: {"id": 1, "text": texte, "entities": [
        {"type": "nom", "start": d, "end": f} for d, f in debut_fin]}}


def pred(spans):
    return {1: {"id": 1, "entities": [{"type": "nom", "start": d, "end": f}
                                       for d, f in spans]}}


class LeakHorsCiviliteTest(unittest.TestCase):
    TEXTE = "Mme Sophie Verdier"

    def test_nom_entierement_masque(self):
        r = lc.mesure(doc(self.TEXTE, [(0, 18)]), pred([(0, 18)]))
        self.assertEqual(r[:3], (0, 0, 0))

    def test_civilite_seule_en_clair(self):
        r = lc.mesure(doc(self.TEXTE, [(0, 18)]), pred([(4, 18)]))
        self.assertEqual(r[:3], (3, 3, 0))

    def test_civilite_et_prenom_en_clair(self):
        r = lc.mesure(doc(self.TEXTE, [(0, 18)]), pred([(11, 18)]))
        # « Mme » (3) + « Sophie » (6) en clair.
        self.assertEqual(r[:3], (9, 3, 6))
        self.assertEqual(r[3], {"Sophie": 6})

    def test_mention_absente_des_predictions(self):
        r = lc.mesure(doc(self.TEXTE, [(0, 18)]), {})
        self.assertEqual(r[:3], (3 + 6 + 7, 3, 13))

    def test_un_span_de_n_importe_quel_type_protege(self):
        p = {1: {"id": 1, "entities": [{"type": "adresse", "start": 0,
                                         "end": 18}]}}
        self.assertEqual(lc.mesure(doc(self.TEXTE, [(0, 18)]), p)[:3],
                         (0, 0, 0))

    def test_civilite_insensible_a_la_casse_et_au_point(self):
        r = lc.mesure(doc("M. Verdier", [(0, 10)]), {})
        self.assertEqual(r[:3], (2 + 7, 2, 7))

    def test_les_autres_types_sont_ignores(self):
        d = {1: {"id": 1, "text": "a@example.fr", "entities": [
            {"type": "email", "start": 0, "end": 12}]}}
        self.assertEqual(lc.mesure(d, {})[:3], (0, 0, 0))


if __name__ == "__main__":
    unittest.main()
