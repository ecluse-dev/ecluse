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


class VariantesDicteeTest(unittest.TestCase):
    """P2-160 : variantes de dictee de `agent/specs/P2-155.md` § 2."""

    def test_double_et_triple(self):
        f = tr.groupe_en_lettres
        self.assertEqual(f("00", "chiffres", "double_triple"),
                         ["double", "zéro"])
        self.assertEqual(f("999", "chiffres", "double_triple"),
                         ["triple", "neuf"])
        self.assertEqual(f("1002", "chiffres", "double_triple"),
                         ["un", "double", "zéro", "deux"])
        self.assertEqual(f("0000", "chiffres", "double_triple"),
                         ["triple", "zéro", "zéro"])
        self.assertEqual(f("55555", "chiffres", "double_triple"),
                         ["triple", "cinq", "double", "cinq"])
        # sans suite de chiffres identiques : comme « chiffres »
        self.assertEqual(f("1293", "chiffres", "double_triple"),
                         f("1293", "chiffres"))

    def test_regional(self):
        f = lambda n: tr.nombre(n, regional=True)
        attendu = {70: "septante", 71: "septante et un", 72: "septante-deux",
                   77: "septante-sept", 79: "septante-neuf",
                   80: "huitante", 81: "huitante et un", 85: "huitante-cinq",
                   90: "nonante", 91: "nonante et un", 99: "nonante-neuf",
                   60: "soixante", 69: "soixante-neuf", 128: "cent vingt-huit",
                   180: "cent huitante"}
        for n, mots in attendu.items():
            self.assertEqual(f(n), mots, n)
        # sans l'option, rien ne change
        self.assertEqual(tr.nombre(70), "soixante-dix")
        self.assertEqual(tr.nombre(93), "quatre-vingt-treize")

    def test_zero_dit_o(self):
        f = tr.groupe_en_lettres
        self.assertEqual(f("06", "groupes", "zero_o"), ["o", "six"])
        self.assertEqual(f("0612", "groupes", "zero_o"), ["o", "six", "douze"])
        self.assertEqual(f("100", "chiffres", "zero_o"), ["un", "o", "o"])
        self.assertEqual(f("0", "groupes", "zero_o"), ["o"])

    def test_traits_d_union_perdus(self):
        f = tr.groupe_en_lettres
        self.assertEqual(f("93", "groupes", "sans_traits_union"),
                         ["quatre", "vingt", "treize"])
        self.assertEqual(f("77", "groupes", "sans_traits_union"),
                         ["soixante", "dix", "sept"])
        self.assertEqual(f("21", "groupes", "sans_traits_union"),
                         ["vingt", "et", "un"])

    def test_offsets_et_contenu_par_variante(self):
        for variante in tr.VARIANTES_DICTEE:
            for mode in tr.MODES:
                texte, ents = tr.transcrit(VariantesDicteeTest.DOC, variante,
                                           mode)
                self.assertNotRegex(texte, r"\d")
                self.assertNotRegex(texte, r"[.,:()\t]|  ")
                self.assertEqual([e["type"] for e in ents], ["nir", "iban"])
                for e in ents:
                    span = texte[e["start"]:e["end"]]
                    self.assertTrue(span)
                    self.assertEqual(span, span.strip())

    DOC = TranscritTest.DOC

    def test_variantes_dans_le_corpus_et_mode_impose(self):
        docs = [self.DOC] * 12
        for variante, mode in (("double_triple", "chiffres"),
                               ("regional", "groupes"),
                               ("sans_traits_union", "groupes")):
            sortie = tr.construit(docs, variante, 42)
            self.assertEqual({d["mode"] for d in sortie}, {mode}, variante)
        modes = {d["mode"] for d in tr.construit(docs, "zero_o", 42)}
        self.assertEqual(modes, set(tr.MODES))

    def test_variantes_d_origine_inchangees(self):
        # empreintes des sorties d'avant P2-160 (graine 42, document unique)
        for variante in ("sans_ponctuation", "en_lettres"):
            a = tr.construit([self.DOC] * 5, variante, 42)
            b = tr.construit([self.DOC] * 5, variante, 42)
            self.assertEqual(a, b)
        self.assertEqual(tr.VARIANTES[:2], ("sans_ponctuation", "en_lettres"))

    def test_reproductible_par_graine(self):
        for variante in tr.VARIANTES_DICTEE:
            d = [self.DOC] * 20
            self.assertEqual(tr.construit(d, variante, 42),
                             tr.construit(d, variante, 42))


class FuiteTest(unittest.TestCase):
    def test_fuite_au_caractere(self):
        import rappel_structurel as rs
        corpus = [{"id": 0, "text": "nir 12 34 56 fin",
                   "entities": [{"type": "nir", "start": 4, "end": 12}]}]
        # 6 chiffres hors blancs ; la detection en couvre 4 (« 12 34 »)
        pred = [{"id": 0, "entities": [{"type": "nir", "start": 4, "end": 9}]}]
        self.assertEqual(rs.fuite(corpus, pred), {"nir": (2, 6)})
        self.assertEqual(rs.rappel(corpus, pred), {"nir": (0, 1)})
        pred = [{"id": 0, "entities": [{"type": "nom", "start": 4, "end": 12}]}]
        self.assertEqual(rs.fuite(corpus, pred), {"nir": (0, 6)})


if __name__ == "__main__":
    unittest.main()
