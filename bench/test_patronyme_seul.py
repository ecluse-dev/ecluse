#!/usr/bin/env python3
"""Tests du scoreur de patronyme seul et du témoin de tournures sans nom
(P2-218) : `python3 -m unittest discover -s bench`. Données synthétiques."""

import unittest

import generate_corpus_tournures_sans_nom as gt
import score_patronyme_seul as sp
import score_tournures_sans_nom as st


def doc(texte, nom):
    a = texte.index(nom)
    return {"id": 0, "text": texte,
            "entities": [{"type": "nom", "start": a, "end": a + len(nom)}]}


class Tournures(unittest.TestCase):
    def test_reconnait_les_cinq_tournures(self):
        cas = {
            "Note : le dossier de Xyz est transmis.": "dossier de",
            "Au dossier de Xyz : pièces.": "dossier de",
            "Rendez-vous reporté à la demande de Xyz ; suite.": "à la demande de",
            "Suite à l'entretien avec Xyz, le suivi.": "entretien avec",
            "Compte rendu : Xyz a confirmé la réception.": "sujet : a confirmé",
            "Xyz rappelle demain.": "sujet : rappelle",
            "Courrier adressé à Xyz.": "adressé à",
            "Xyz est là.": "autre",
        }
        for texte, attendu in cas.items():
            a = texte.index("Xyz")
            self.assertEqual(sp.tournure(texte, a, a + 3), attendu, texte)

    def test_la_tournure_ne_traverse_pas_les_lignes(self):
        t = "Voir le dossier de\nXyz est là."
        a = t.index("Xyz")
        self.assertEqual(sp.tournure(t, a, a + 3), "autre")


class Mesure(unittest.TestCase):
    def test_compte_le_manque_hors_civilite_par_mode(self):
        d = doc("Courrier adressé à Xyz.", "Xyz")
        d2 = dict(doc("Voir Mme Abc Xyz ici.", "Mme Abc Xyz"), id=1)
        corpus = [d, d2]
        # Document par document : rien de masqué ; session : tout le patronyme.
        pred_doc = [{"id": 0, "mentions": []}, {"id": 1, "mentions": []}]
        pred_ses = [
            {"id": 0, "mentions": [{"start": 19, "end": 22}]},
            {"id": 1, "mentions": [{"start": 9, "end": 16}]},  # Abc Xyz
        ]
        r = sp.mesure(corpus, pred_doc, pred_ses)
        self.assertEqual(r[("seul", "adressé à")]["noms"], 1)
        self.assertEqual(r[("seul", "adressé à")]["document"], 1)
        self.assertEqual(r[("seul", "adressé à")]["session"], 0)
        # La civilité laissée en clair ne compte pas ; « Abc Xyz » couvert.
        self.assertEqual(r[("complet", "*")]["noms"], 1)
        self.assertEqual(r[("complet", "*")]["session"], 0)
        self.assertEqual(r[("complet", "*")]["document"], 1)

    def test_aucune_valeur_dans_la_sortie(self):
        import contextlib
        import io
        d = doc("Courrier adressé à Xyzzy.", "Xyzzy")
        r = sp.mesure([d], [{"id": 0, "mentions": []}],
                      [{"id": 0, "mentions": []}])
        tampon = io.StringIO()
        with contextlib.redirect_stdout(tampon):
            sp.affiche(r)
        self.assertNotIn("Xyzzy", tampon.getvalue())


class Temoin(unittest.TestCase):
    def test_reproductible_sans_entite_et_assez_de_phrases(self):
        a = gt.construit(400, 42)
        self.assertEqual(a, gt.construit(400, 42))
        self.assertGreaterEqual(len(a), 400)
        self.assertTrue(all(d["entities"] == [] for d in a))
        self.assertEqual({d["tournure"] for d in a}, set(gt.TOURNURES))
        self.assertEqual({d["genre"] for d in a}, set(gt.GENRES))

    def test_cases_a_parts_egales(self):
        import collections
        c = collections.Counter((d["tournure"], d["genre"])
                                for d in gt.construit(400, 42))
        self.assertEqual(set(c.values()), {20})

    def test_scoreur_compte_les_masques(self):
        corpus = gt.construit(40, 1)
        pred = [{"id": d["id"], "entities": (
            [{"type": "nom", "start": 0, "end": 3}] if d["id"] == 0 else [])}
            for d in corpus]
        par, types = st.mesure(corpus, pred)
        self.assertEqual(par[("total", "*")]["masques"], 1)
        self.assertEqual(types["nom"], 1)


if __name__ == "__main__":
    unittest.main()
