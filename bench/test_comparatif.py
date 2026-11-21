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


class TestAnnotationComplement(unittest.TestCase):
    """Annotation propre au comparatif (P2-247), textes synthétiques."""

    def doc(self, texte, entites=()):
        return {"id": 0, "text": texte, "entities": list(entites),
                "source": "v3", "dossier": "v3-0"}

    def test_nom_telephone_dossier_ajoutes_avec_positions(self):
        t = "Rappel : Nadia Roux est attendu, tel 07 83 66 74 28, dossier n° 18220919."
        sortie, comptes = c.annote_complement([self.doc(t)])
        ajoutes = {e["type"]: t[e["start"]:e["end"]]
                   for e in sortie[0]["entities"] if e.get("ajoute")}
        self.assertEqual(ajoutes, {"nom": "Nadia Roux",
                                   "telephone": "07 83 66 74 28",
                                   "dossier": "18220919"})
        self.assertEqual(comptes, {("v3", "nom"): 1, ("v3", "telephone"): 1,
                                   ("v3", "dossier"): 1})

    def test_pieges_non_annotes(self):
        for t in ["Le SIREN de la société est 367365764.",
                  "Le SIRET de l'établissement est 20812191361934.",
                  "Le numéro 18350305648 ne correspond à aucun praticien connu.",
                  "L'IBAN FR5057939542874381561497805 a été refusé."]:
            sortie, comptes = c.annote_complement([self.doc(t)])
            self.assertEqual(comptes, {}, t)
            self.assertEqual(sortie[0]["entities"], [])

    def test_recouvrement_avec_une_entite_existante_ignore(self):
        t = "Nadia Roux"
        e = ent("nom", 0, 10)
        sortie, comptes = c.annote_complement([self.doc(t, [e])])
        self.assertEqual(comptes, {})
        self.assertEqual(sortie[0]["entities"], [e])

    def test_copie_sans_toucher_l_original(self):
        d = self.doc("Rappel : Jean Fontaine est attendu.")
        c.annote_complement([d])
        self.assertEqual(d["entities"], [])


if __name__ == "__main__":
    unittest.main()
