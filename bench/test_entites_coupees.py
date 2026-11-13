"""Tests de `entites_coupees.py` (P2-173). Textes synthetiques."""

import unittest

from entites_coupees import coupees, ligne


def doc(i, texte, entites):
    return {"id": i, "text": texte, "entities": entites}


class EntitesCoupees(unittest.TestCase):
    def setUp(self):
        t = "Suivi au Centre\nHospitalier de Dole depuis mars."
        s = t.index("Centre")
        e = t.index(" depuis")
        self.corpus = [doc(0, t, [{"type": "etablissement", "start": s,
                                   "end": e}])]
        self.s, self.e, self.t = s, e, t

    def test_entierement_en_clair(self):
        r = coupees(self.corpus, [{"id": 0, "entities": []}])
        self.assertEqual(r["etablissement"]["coupees"], 1)
        self.assertEqual(r["etablissement"]["en_clair"], 1)
        # Blancs (dont la fin de ligne) non comptes.
        self.assertEqual(r["etablissement"]["caracteres_en_clair"],
                         len("CentreHospitalierdeDole"))

    def test_partielle(self):
        fin = self.t.index("\n")
        r = coupees(self.corpus, [{"id": 0, "entities": [
            {"type": "etablissement", "start": self.s, "end": fin}]}])
        self.assertEqual(r["etablissement"]["partielles"], 1)
        self.assertEqual(r["etablissement"]["caracteres_en_clair"],
                         len("HospitalierdeDole"))

    def test_couverte_quel_que_soit_le_type(self):
        r = coupees(self.corpus, [{"id": 0, "entities": [
            {"type": "nom", "start": self.s, "end": self.e}]}])
        self.assertEqual(r["etablissement"]["couvertes"], 1)
        self.assertEqual(r["etablissement"]["caracteres_en_clair"], 0)

    def test_entite_sur_une_ligne_ignoree(self):
        t = "Suivi au CH de Vesoul.\nRien d'autre."
        c = [doc(1, t, [{"type": "etablissement", "start": 9, "end": 21}])]
        r = coupees(c, [{"id": 1, "entities": []}])
        self.assertEqual(r["etablissement"]["coupees"], 0)

    def test_document_refuse_exclu(self):
        r = coupees(self.corpus, [{"id": 0, "refuse": True}])
        self.assertEqual(r["etablissement"]["coupees"], 0)

    def test_autres_types_ignores(self):
        t = "Mme Odile\nVerdier."
        c = [doc(2, t, [{"type": "nom", "start": 0, "end": 17}])]
        r = coupees(c, [{"id": 2, "entities": []}])
        self.assertEqual(sum(v["coupees"] for v in r.values()), 0)

    def test_ligne(self):
        r = coupees(self.corpus, [{"id": 0, "entities": []}])
        self.assertIn("etablissement 1 coupées (0 couvertes, 0 en partie en "
                      "clair, 1 entièrement en clair, 23 car.)", ligne(r))


if __name__ == "__main__":
    unittest.main()
