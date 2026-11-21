#!/usr/bin/env python3
"""Tests de la sonde « prénom + verbe » (P2-240) :
`python3 -m unittest discover -s bench`. Données synthétiques."""

import contextlib
import io
import os
import re
import unittest

import generate_corpus_prenom_verbe as g
import score_prenom_verbe as s

ICI = os.path.dirname(os.path.abspath(__file__))
LISTE = os.path.join(ICI, "..", "packages", "ecluse_redact", "lib", "src",
                     "heuristics", "verbes_conjugues.dart")


def verbes_du_detecteur():
    with open(LISTE, encoding="utf-8") as f:
        texte = f.read()
    corps = texte[texte.index("{\n"):texte.index("};")]
    corps = re.sub(r"//[^\n]*", "", corps)
    return set(re.findall(r"'([^']+)'", corps))


class Generateur(unittest.TestCase):
    def setUp(self):
        self.docs = g.construit(42)

    def test_effectifs(self):
        self.assertEqual(len(g.PRENOMS), 10)
        self.assertEqual(len(g.COURANTS), 40)
        self.assertEqual(len(g.RESERVE), 20)
        self.assertGreaterEqual(len(g.RESERVE2), 60)
        self.assertEqual(len(set(g.RESERVE2)), len(g.RESERVE2))
        self.assertEqual(len(self.docs), 10 * (40 + 20 + len(g.RESERVE2)))

    def test_positions(self):
        for d in self.docs:
            t = d["text"]
            self.assertIn(t[d["mot"]["start"]:d["mot"]["end"]], g.PRENOMS)
            verbe = t[d["verbe"]["start"]:d["verbe"]["end"]]
            self.assertIn(verbe, g.COURANTS + g.RESERVE + g.RESERVE2)
            self.assertEqual(d["entities"], [{"type": "nom", "start": 0,
                                              "end": d["mot"]["end"]}])

    def test_reproductible(self):
        self.assertEqual(self.docs, g.construit(42))
        self.assertNotEqual([d["text"] for d in self.docs],
                            [d["text"] for d in g.construit(7)])

    def test_reserve_absente_de_la_liste_du_detecteur(self):
        liste = verbes_du_detecteur()
        self.assertGreater(len(liste), 100)
        self.assertEqual([v for v in g.RESERVE if v in liste], [])

    def test_seconde_reserve_absente_de_la_liste_et_de_la_premiere(self):
        liste = verbes_du_detecteur()
        self.assertEqual([v for v in g.RESERVE2 if v in liste], [])
        self.assertEqual([v for v in g.RESERVE2 if v in g.RESERVE], [])
        self.assertEqual([v for v in g.RESERVE2 if v in g.COURANTS], [])

    def test_courants_dans_la_liste_ou_mots_outils(self):
        liste = verbes_du_detecteur()
        # Mots outils déjà écartés par le détecteur (_motsOutils).
        outils = {"est", "fait", "dit", "vient", "veut", "doit", "peut",
                  "entre", "arrive"}
        manque = [v for v in g.COURANTS if v not in liste and v not in outils]
        self.assertEqual(manque, [])


def formes_reconnues():
    """Liste fermée, formes dérivées (pluriel, futur) et rien d'autre."""
    liste = verbes_du_detecteur()
    formes = set(liste)
    for v in liste:
        if v.endswith("e"):
            formes |= {v + "nt", v + "ra"}
    return formes


class ListeEtendue(unittest.TestCase):
    """P2-242 : aucune forme reconnue comme verbe n'est un nom annoté ni un
    prénom courant (sinon un patronyme passerait en clair derrière un prénom).
    Les corpus sont ceux déjà générés dans bench/ : sans eux, le test saute."""

    def test_aucun_nom_annote_ni_prenom_courant(self):
        import mesure_terminaisons_verbes as m
        noms = m.mots_annotes()
        if len(noms) < 50:
            self.skipTest("corpus de noms non générés (bench/etat.sh)")
        prenoms = m.prenoms_courants()
        collisions = sorted(
            f for f in formes_reconnues()
            if f in noms or m.sans_accent(f) in prenoms)
        self.assertEqual(collisions, [])

    def test_terminaisons_retenues_sans_nom_annote(self):
        import mesure_terminaisons_verbes as m
        noms = m.mots_annotes()
        if len(noms) < 50:
            self.skipTest("corpus de noms non générés (bench/etat.sh)")
        prenoms = m.prenoms_courants()
        for fin in ("ifie", "ionne", "ifient", "ionnent", "isent", "issent",
                    "ivent", "iera"):
            self.assertEqual([n for n in noms if n.endswith(fin)], [], fin)
            self.assertEqual(
                [p for p in prenoms if p.endswith(m.sans_accent(fin))], [], fin)

    def test_liste_assez_fournie(self):
        self.assertGreater(len(verbes_du_detecteur()), 450)


class Scoreur(unittest.TestCase):
    def test_comptes(self):
        docs = g.construit(42)
        pred = []
        for d in docs:
            fin = d["mot"]["end"] if d["famille"] == "courants" \
                else d["verbe"]["end"]
            pred.append({"id": d["id"], "entities": [
                {"type": "nom", "start": 0, "end": fin}]})
        par = s.mesure(docs, pred)
        self.assertEqual(par["*"]["verbes"], 200 + 10 * len(g.RESERVE2))
        self.assertEqual(par["courants"]["verbes"], 0)
        self.assertEqual(par["*"]["fuites"], 0)
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            s.affiche(par)
        self.assertIn("%d verbes masqués, 0 prénoms en clair"
                      % (200 + 10 * len(g.RESERVE2)), buf.getvalue())

    def test_fuite_comptee(self):
        docs = g.construit(42)
        pred = [{"id": d["id"], "entities": []} for d in docs]
        self.assertEqual(s.mesure(docs, pred)["*"]["fuites"], len(docs))

    def test_refus_prediction_absente(self):
        with self.assertRaises(KeyError):
            s.mesure(g.construit(42), [])


if __name__ == "__main__":
    unittest.main()
