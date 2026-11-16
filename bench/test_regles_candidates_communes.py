#!/usr/bin/env python3
"""Tests des regles candidates pour les communes en capitales (P2-206) :
`python3 -m unittest discover -s bench`. Donnees synthetiques ; referentiel
public versionne."""

import unittest

import generate_corpus_commune_neutre as gn
import regles_candidates_communes as rc


class Referentiel(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.communes = rc.charge_referentiel()
        cls.neutres = rc.mots_neutres()

    def etendues(self, texte, regle, capitales=False):
        return rc.etendues(texte, regle, self.communes, self.neutres,
                           capitales)

    def test_normalisation(self):
        self.assertEqual(rc.norme("Château-Chinon (Ville)"),
                         "CHATEAU CHINON VILLE")
        self.assertEqual(rc.norme("ŒUVRES  d’Art"), "OEUVRES D ART")

    def test_nom_exact_commune_longue(self):
        t = "01411 FLAVIGNY LE GRAND ET BEAURAIN"
        self.assertEqual(self.etendues(t, "exact_prefixe"), [(0, len(t))])
        self.assertEqual(self.etendues(t, "exact_ligne"), [(0, len(t))])

    def test_texte_ordinaire_n_est_pas_une_commune(self):
        t = "70000 VESOUL SERVICE DES ADMISSIONS BATIMENT B"
        # Le prefixe « VESOUL » est une commune : le nom exact s'arrete la ;
        # la ligne entiere n'en est pas une.
        self.assertEqual(self.etendues(t, "exact_prefixe"), [(0, 12)])
        self.assertEqual(self.etendues(t, "exact_ligne"), [])

    def test_aucun_nombre_a_cinq_chiffres_rien(self):
        self.assertEqual(self.etendues("SON ACCORD", "exact_prefixe"), [])

    def test_mot_neutre_commune_est_leve_par_le_nom_exact(self):
        self.assertEqual(self.etendues("08061 SON", "exact_ligne"), [(0, 9)])
        self.assertEqual(self.etendues("70000 EUROS", "exact_prefixe"), [])

    def test_fin_de_ligne_garde_la_regle_du_mot_neutre(self):
        self.assertEqual(self.etendues("08061 SON", "fin_de_ligne"), [])
        self.assertEqual(self.etendues("70000 EUROS HORS TAXES",
                                       "fin_de_ligne"), [])

    def test_fin_de_ligne_s_arrete_a_un_mot_ordinaire_ou_un_nombre(self):
        self.assertEqual(self.etendues("70000 Vesoul à 9 h", "fin_de_ligne"),
                         [])
        t = "70000 VESOUL SERVICE DES ADMISSIONS"
        self.assertEqual(self.etendues(t, "fin_de_ligne"), [(0, len(t))])

    def test_la_regle_ne_vit_que_dans_les_capitales(self):
        self.assertEqual(self.etendues("Dossier 90402 Les Places.",
                                       "exact_ligne", True), [])

    def test_union_et_en_clair(self):
        t = "01411 FLAVIGNY LE GRAND ET BEAURAIN"
        pred = {"entities": [{"type": "adresse", "start": 0, "end": 26}]}
        self.assertTrue(rc.en_clair(t, 0, len(t), rc.couverts_de(pred)))
        c = rc.couverts_de(pred, self.etendues(t, "exact_prefixe"))
        self.assertFalse(rc.en_clair(t, 0, len(t), c))


class TemoinCommuneNeutre(unittest.TestCase):
    def test_les_quinze_noms_du_referentiel(self):
        noms = gn.noms_neutres()
        self.assertEqual(len(noms), 15)
        for attendu in ("SON", "VERS", "SOUS PARSAT", "LES PLACES"):
            self.assertIn(attendu, noms)

    def test_reproductible_aucune_entite(self):
        a = gn.construit(120, 42)
        self.assertEqual(a, gn.construit(120, 42))
        self.assertNotEqual(a, gn.construit(120, 43))
        self.assertTrue(all(d["entities"] == [] for d in a))
        self.assertEqual([d["id"] for d in a], list(range(120)))

    def test_forme_et_casse(self):
        for d in gn.construit(120, 42):
            self.assertRegex(d["text"], r"(?<!\d)\d{5} ")
            if d["casse"] == "capitales":
                self.assertEqual(d["text"], d["text"].upper())
            else:
                self.assertRegex(d["text"], r"[a-z]")

    def test_tous_les_noms_et_les_deux_axes_sont_couverts(self):
        docs = gn.construit(400, 42)
        self.assertEqual({d["nom"] for d in docs}, set(gn.noms_neutres()))
        self.assertEqual({d["famille"] for d in docs}, {"fin", "suite"})
        self.assertEqual({d["casse"] for d in docs}, {"capitales", "ordinaire"})


if __name__ == "__main__":
    unittest.main()
