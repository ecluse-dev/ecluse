#!/usr/bin/env python3
"""Tests de la règle de score et de l'échantillon du comparatif (P2-224).
`python3 -m unittest discover -s bench` (depuis la racine). Données
synthétiques ; aucun outil externe n'est lancé."""

import unittest

import comparatif as c

TEXTE = "Mme Camille Verdier habite 12 rue des Lilas."


def ent(t, a, b):
    return {"type": t, "start": a, "end": b}


class TestScore(unittest.TestCase):
    def test_civilite_retiree_du_nom(self):
        e = ent("nom", 0, 20)  # « Mme Camille Verdier »
        self.assertEqual(c.borne_sans_civilite(TEXTE, e), (3, 20))
        # le nom sans sa civilité, couvert : l'entité est couverte
        self.assertTrue(c.couverte(TEXTE, e, [(4, 20)]))
        # un type autre que nom garde sa borne
        self.assertEqual(c.borne_sans_civilite(TEXTE, ent("adresse", 28, 43)),
                         (28, 43))

    def test_couverture_partielle_refusee(self):
        e = ent("nom", 4, 20)
        self.assertFalse(c.couverte(TEXTE, e, [(4, 12)]))
        self.assertTrue(c.couverte(TEXTE, e, [(4, 12), (12, 20)]))

    def test_type_predit_indifferent_et_blancs_ignores(self):
        e = ent("nom", 4, 20)
        # le trou est l'espace entre prénom et nom : sans effet
        self.assertTrue(c.couverte(TEXTE, e, [(4, 11), (12, 20)]))

    def test_nom_reduit_a_une_civilite_garde_sa_borne(self):
        self.assertEqual(c.borne_sans_civilite("Dr Dupont", ent("nom", 0, 2)),
                         (0, 2))

    def test_score_et_faux_positifs(self):
        docs = [
            {"id": 0, "text": TEXTE, "entities": [ent("nom", 4, 20)]},
            {"id": 1, "text": "Rien ici.", "entities": []},
            {"id": 2, "text": "Rien là non plus.", "entities": []},
        ]
        par_type, faux = c.score(docs, {0: [(4, 20)], 1: [(0, 4)]})
        self.assertEqual(par_type, {"nom": [1, 1]})
        self.assertEqual(faux, [1, 2])


class TestEchantillon(unittest.TestCase):
    def corpus(self):
        v3 = [{"id": i, "text": f"v3 {i}", "entities": []} for i in range(100)]
        dossiers = [{"id": i, "text": f"d {i}", "entities": [],
                     "dossier": i // 4, "rang": i % 4} for i in range(60)]
        flou = [{"id": i, "text": f"f {i}",
                 "entities": [ent("adresse" if i % 2 else "nom", 0, 1)]}
                for i in range(80)]
        return v3, dossiers, flou

    def test_reproductible_et_dossiers_entiers(self):
        a = c.echantillon(*self.corpus())
        b = c.echantillon(*self.corpus())
        self.assertEqual(a, b)
        self.assertEqual([d["id"] for d in a], list(range(len(a))))
        n_dossiers = [d for d in a if d["source"] == "dossiers"]
        self.assertLessEqual(len(n_dossiers), 50)
        self.assertEqual(len(n_dossiers) % 4, 0)  # dossiers entiers
        self.assertEqual(sum(d["source"] == "v3" for d in a), 50)
        self.assertEqual(sum(d["source"] == "flou" for d in a), 40)
        self.assertTrue(all(d["entities"][0]["type"] == "adresse"
                            for d in a if d["source"] == "flou"))


class TestTemoin(unittest.TestCase):
    """Témoin sans donnée personnelle (P2-246) : mesure et générateur."""

    def test_mesure_documents_caracteres_et_types(self):
        docs = [{"id": 0, "text": "Salle 204 libre.", "entities": []},
                {"id": 1, "text": "Rien ici.", "entities": []}]
        # deux prédictions de types différents qui se chevauchent sur « 204 »
        m = c.mesure_temoin(docs, {0: [(0, 9, "adresse"), (6, 9, "nom")]})
        self.assertEqual(m["docs"], [1, 2])
        self.assertEqual(m["car"], [8, 22])  # « Salle 204 » : 8 hors blanc ; total 14 + 8
        self.assertEqual(m["types"], {"adresse": [1, 8], "nom": [1, 3]})

    def test_score_tolere_le_type_predit(self):
        e = ent("nom", 4, 20)
        self.assertTrue(c.couverte(TEXTE, e, [(4, 20, "PER")]))

    def test_generateur_reproductible_sans_entite_ni_identifiant(self):
        import re
        import generate_corpus_temoin_sans_pii as g
        a, b = g.genere(480, 42), g.genere(480, 42)
        self.assertEqual(a, b)
        self.assertGreaterEqual(len(a), 400)
        self.assertEqual(len(set(d["famille"] for d in a)), 6)
        self.assertNotEqual(a, g.genere(480, 7))
        for d in a:
            self.assertEqual(d["entities"], [])
            t = d["text"]
            self.assertNotRegex(t, r"@")                       # pas d'e-mail
            self.assertNotRegex(t, r"\b0\d([ .]?\d{2}){4}\b")  # pas de téléphone
            self.assertNotRegex(t, r"\b[A-Z]{2}\d{2}\b")      # pas d'IBAN
            self.assertNotRegex(t, r"\d{9,}")                   # pas de long numéro


if __name__ == "__main__":
    unittest.main()
