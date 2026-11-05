#!/usr/bin/env python3
"""Tests du corpus « style transcrit » (P2-98) :
`python3 -m unittest discover -s bench` (depuis la racine). Donnees
synthetiques, aucune lecture reseau."""

import unittest

import generate_corpus_transcrit as tr

_TEXTE = "Paie de Paul Lefèvre : NIR 1  93  08, service RH (FR80\t72)."


def _span(typ, morceau):
    debut = _TEXTE.index(morceau)
    return {"type": typ, "start": debut, "end": debut + len(morceau)}


class NombresTest(unittest.TestCase):
    def test_nombres_francais(self):
        attendu = {0: "zéro", 1: "un", 16: "seize", 17: "dix-sept",
                   21: "vingt et un", 22: "vingt-deux", 70: "soixante-dix",
                   71: "soixante et onze", 77: "soixante-dix-sept",
                   80: "quatre-vingts", 81: "quatre-vingt-un",
                   91: "quatre-vingt-onze", 99: "quatre-vingt-dix-neuf",
                   100: "cent", 128: "cent vingt-huit", 200: "deux cents",
                   997: "neuf cent quatre-vingt-dix-sept"}
        for n, mots in attendu.items():
            self.assertEqual(tr.nombre(n), mots, n)

    def test_zeros_de_tete_dits(self):
        self.assertEqual(tr.groupe_en_lettres("08", "groupes"),
                         ["zéro", "huit"])
        self.assertEqual(tr.groupe_en_lettres("0612", "groupes"),
                         ["zéro", "six", "douze"])
        self.assertEqual(tr.groupe_en_lettres("093", "chiffres"),
                         ["zéro", "neuf", "trois"])


class TranscritTest(unittest.TestCase):
    DOC = {"id": 7, "text": _TEXTE,
           "entities": [_span("nir", "1  93  08"), _span("iban", "FR80\t72")]}

    def test_offsets_exacts_et_texte(self):
        for variante in tr.VARIANTES:
            for mode in tr.MODES:
                texte, ents = tr.transcrit(self.DOC, variante, mode)
                self.assertEqual(texte, texte.lower())
                self.assertNotRegex(texte, r"[.,:()\t]|  ")
                self.assertEqual([e["type"] for e in ents], ["nir", "iban"])
                for e in ents:
                    span = texte[e["start"]:e["end"]]
                    self.assertEqual(span, span.strip())
                    self.assertTrue(span)

    def test_sans_ponctuation_garde_les_chiffres(self):
        texte, ents = tr.transcrit(self.DOC, "sans_ponctuation", None)
        self.assertEqual(texte[ents[0]["start"]:ents[0]["end"]], "1 93 08")
        self.assertEqual(texte[ents[1]["start"]:ents[1]["end"]], "fr80 72")

    def test_en_lettres_groupes(self):
        texte, ents = tr.transcrit(self.DOC, "en_lettres", "groupes")
        self.assertEqual(texte[ents[0]["start"]:ents[0]["end"]],
                         "un quatre-vingt-treize zéro huit")
        self.assertNotRegex(texte, r"\d")

    def test_reproductible_par_graine(self):
        d = [self.DOC] * 20
        self.assertEqual(tr.construit(d, "en_lettres", 42),
                         tr.construit(d, "en_lettres", 42))
        modes = {x["mode"] for x in tr.construit(d, "en_lettres", 42)}
        self.assertEqual(modes, set(tr.MODES))


if __name__ == "__main__":
    unittest.main()
