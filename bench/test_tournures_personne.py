#!/usr/bin/env python3
"""Tests du témoin élargi des tournures de personne (P2-226) :
`python3 -m unittest discover -s bench`. Données synthétiques."""

import contextlib
import io
import os
import re
import unittest

import generate_corpus_tournures_personne as gp
import generate_corpus_tournures_sans_nom as gt
import score_tournures_personne as sp


class Generateur(unittest.TestCase):
    def setUp(self):
        self.docs = gp.construit(42)

    def test_chaque_mot_dans_chaque_tournure(self):
        n = sum(len(m) for m in gp.FAMILLES.values()) * len(gp.TOURNURES)
        self.assertEqual(len(self.docs), n)
        cases = {(d["famille"], d["tournure"], d["text"][d["mot"]["start"]:d["mot"]["end"]])
                 for d in self.docs}
        self.assertEqual(len(cases), n)

    def test_familles_d_au_moins_vingt_mots_distincts(self):
        self.assertEqual(len(gp.FAMILLES), 5)
        for fam, mots in gp.FAMILLES.items():
            self.assertGreaterEqual(len(set(mots)), 20, fam)

    def test_aucun_nom_commun_du_temoin_de_p2_218(self):
        anciens = set(gt.COMMUN_MIN) | set(gt.COMMUN_MAJ)
        anciens_bas = {m.lower() for m in anciens}
        for mots in gp.FAMILLES.values():
            for m in mots:
                self.assertNotIn(m.lower(), anciens_bas, m)

    def test_memes_tournures_et_gabarits_que_p2_218(self):
        for t in gp.TOURNURES:
            self.assertEqual(gp.GABARITS[t], gt.GABARITS[t], t)

    def test_positions_et_annotations(self):
        for d in self.docs:
            mot = d["text"][d["mot"]["start"]:d["mot"]["end"]]
            self.assertIn(mot, gp.FAMILLES[d["famille"]])
            if d["famille"] in gp.PERSONNES:
                self.assertEqual(d["entities"],
                                 [{"type": "nom", **d["mot"]}])
            else:
                self.assertEqual(d["entities"], [])

    def test_patronymes_communes_hors_de_la_table(self):
        """Chaque patronyme-commune a de 10 000 à moins de 100 000 habitants :
        la table `communes_grandes.dart` (seuil de 100 000, P2-239) n'en
        contient aucun, donc aucun n'est écarté derrière « à la demande de »."""
        import gzip
        import unicodedata
        racine = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
        chemin = os.path.join(racine, "packages", "ecluse_redact", "lib", "src",
                              "heuristics", "communes_grandes.dart")
        with open(chemin, encoding="utf-8") as f:
            table = set(re.findall(r"^  '([^']+)',$", f.read(), re.M))

        def cle(w):
            w = unicodedata.normalize("NFKD", w).encode("ascii", "ignore")
            return re.sub(r"[^A-Z0-9]+", " ", w.decode().upper()).strip()
        pop = {}
        with gzip.open(os.path.join(racine, "packages", "ecluse_reference",
                                    "assets", "geo_communes.csv.gz"),
                       "rt", encoding="utf-8") as f:
            next(f)
            for ligne in f:
                c = ligne.rstrip("\n").split(";")
                if len(c) >= 6 and c[3].strip().isdigit():
                    pop.setdefault(re.sub(r"[^A-Z0-9]+", " ", c[4]).strip(),
                                   []).append(int(c[3]))
        for m in gp.FAMILLES["patronymes_communes"]:
            self.assertNotIn(cle(m), table, m)
            self.assertTrue(any(10000 <= n < 100000 for n in pop.get(cle(m), [])),
                            m)
        for m in gp.FAMILLES["patronymes_noms_communs"]:
            self.assertNotIn(cle(m), table, m)

    def test_reproductible(self):
        self.assertEqual(gp.construit(42), self.docs)


class Score(unittest.TestCase):
    def corpus(self):
        texte = "Compte rendu : Berger a confirmé.\n"
        a = texte.index("Berger")
        perso = {"id": 0, "text": texte, "famille": "patronymes_noms_communs",
                 "tournure": "sujet : a confirmé",
                 "mot": {"start": a, "end": a + 6},
                 "entities": [{"type": "nom", "start": a, "end": a + 6}]}
        texte2 = "Suite à l'entretien avec Madame, le suivi.\n"
        b = texte2.index("Madame")
        role = {"id": 1, "text": texte2, "famille": "roles",
                "tournure": "entretien avec",
                "mot": {"start": b, "end": b + 6}, "entities": []}
        return [perso, role], a, b

    def test_patronyme_masque_seulement_si_couvert_en_entier(self):
        corpus, a, b = self.corpus()
        pred = [{"id": 0, "entities": [{"type": "nom", "start": a, "end": a + 3}]},
                {"id": 1, "entities": []}]
        par, _, _ = sp.mesure(corpus, pred)
        self.assertEqual(par[("patronymes_noms_communs", "*")]["masques"], 0)
        pred[0]["entities"][0]["end"] = a + 6
        par, _, _ = sp.mesure(corpus, pred)
        self.assertEqual(par[("patronymes_noms_communs", "*")]["masques"], 1)

    def test_role_masque_a_tort_des_un_caractere(self):
        corpus, a, b = self.corpus()
        pred = [{"id": 0, "entities": []},
                {"id": 1, "entities": [{"type": "nom", "start": b + 2, "end": b + 3},
                                       {"type": "adresse", "start": 0, "end": 4}]}]
        par, types, hors = sp.mesure(corpus, pred)
        self.assertEqual(par[("roles", "entretien avec")]["masques"], 1)
        self.assertEqual(hors, 1)
        self.assertEqual(types[(False, "nom")], 1)

    def test_aucune_valeur_dans_la_sortie(self):
        docs = gp.construit(42)
        pred = [{"id": d["id"], "entities": d["entities"]} for d in docs]
        sortie = io.StringIO()
        with contextlib.redirect_stdout(sortie):
            sp.affiche(docs, *sp.mesure(docs, pred))
        texte = sortie.getvalue()
        for mots in gp.FAMILLES.values():
            for m in mots:
                self.assertNotIn(m, texte)
        self.assertIn("famille=patronymes_communes : 96 / 96 masqués", texte)
        self.assertIn("famille=roles : 0 / 96 masqués à tort", texte)


if __name__ == "__main__":
    unittest.main()
