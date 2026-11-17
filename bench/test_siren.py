#!/usr/bin/env python3
"""Tests du témoin SIREN / FINESS et de son scoreur (P2-223) :
`python3 -m unittest discover -s bench`. Données synthétiques."""

import contextlib
import io
import unittest

import generate_corpus_siren as gs
import score_siren_finess as sf


class Generateur(unittest.TestCase):
    def test_reproductible_et_a_parts_egales(self):
        a, b = gs.corpus_siren(400, 42), gs.corpus_finess(400, 42)
        self.assertEqual(a, gs.corpus_siren(400, 42))
        self.assertEqual(b, gs.corpus_finess(400, 42))
        self.assertEqual(len(a), 400)
        self.assertEqual(len(b), 400)
        c = {k: 0 for k in [(l, e) for l in gs.LIBELLES for e in gs.ECRITURES]}
        for d in a:
            c[(d["libelle"], d["ecriture"])] += 1
        self.assertEqual(set(c.values()), {50})

    def test_nombres_valides_et_positions_exactes(self):
        for d in gs.corpus_siren(80, 1):
            t = d["text"][d["siren"]["start"]:d["siren"]["end"]]
            ch = sf.chiffres(t, 0, len(t))
            self.assertEqual(len(ch), 9)
            self.assertTrue(sf.luhn(ch))
            self.assertEqual(d["entities"], [])
        for d in gs.corpus_finess(80, 1):
            e = d["entities"][0]
            ch = sf.chiffres(d["text"], e["start"], e["end"])
            self.assertEqual((len(ch), sf.luhn(ch)), (9, True))
            if "siren_voisin" in d:
                v = d["siren_voisin"]
                self.assertTrue(sf.luhn(sf.chiffres(d["text"], v["start"],
                                                    v["end"])))

    def test_libelle_immediat_et_phrase_sont_bien_distincts(self):
        for d in gs.corpus_siren(400, 42):
            avant = d["text"][:d["siren"]["start"]]
            immediat = bool(sf.LIBELLE_IMMEDIAT.search(avant))
            if d["libelle"] == "siren_immediat":
                self.assertTrue(immediat, d["text"])
            if d["libelle"] in ("siren_phrase", "siren_apres", "sans_mot"):
                self.assertFalse(immediat, d["text"])


class Options(unittest.TestCase):
    def test_options_filtrent_ce_qu_elles_disent(self):
        t = "Le SIREN de la société est 123456782."
        a = t.index("123456782")
        doc = {"text": t}
        p = {"type": "finess", "start": a, "end": a + 9, "confidence": 0.5}
        self.assertTrue(sf.garde("base", doc, p))
        self.assertTrue(sf.garde("libelle_immediat", doc, p))
        self.assertFalse(sf.garde("libelle_40", doc, p))
        self.assertFalse(sf.garde("libelle_40_sans_mot_finess", doc, p))
        self.assertFalse(sf.garde("contexte_exige", doc, p))
        haut = dict(p, confidence=0.9)
        self.assertTrue(sf.garde("libelle_40_sans_mot_finess", doc, haut))
        self.assertTrue(sf.garde("contexte_exige", doc, haut))

    def test_prefixe(self):
        doc = {"text": "0123456782 990000000"}
        self.assertTrue(sf.garde("prefixe", doc,
                                 {"start": 1, "end": 10, "confidence": 1}))
        self.assertFalse(sf.garde("prefixe", {"text": "990000000"},
                                  {"start": 0, "end": 9, "confidence": 1}))

    def test_sortie_sans_aucun_texte(self):
        docs = gs.corpus_siren(40, 3)
        preds = {d["id"]: {"id": d["id"], "entities": []} for d in docs}
        fdocs = gs.corpus_finess(40, 3)
        fpreds = {d["id"]: {"id": d["id"], "entities": []} for d in fdocs}
        v3 = [{"id": 0, "text": "SIREN 123456782 fin", "entities": []}]
        res = sf.mesure((v3, {0: {"entities": []}}), (docs, preds),
                        (fdocs, fpreds))
        tampon = io.StringIO()
        with contextlib.redirect_stdout(tampon):
            sf.affiche(res, docs, preds, v3)
        sortie = tampon.getvalue()
        for d in docs[:5]:
            self.assertNotIn(d["text"][d["siren"]["start"]:d["siren"]["end"]],
                             sortie)
        self.assertIn("option=luhn", sortie)


if __name__ == "__main__":
    unittest.main()
