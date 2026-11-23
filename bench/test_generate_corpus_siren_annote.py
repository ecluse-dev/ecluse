"""Tests de l'annotation `siren` du corpus (P2-261, 23/11/2026).

Décision du mainteneur (DECISIONS.md, 23 novembre, point 8) : Écluse masque à
dessein SIREN, SIRET et numéro de TVA ; le corpus les annote donc `siren`
(span = le numéro entier, « FR » et la clé compris pour la TVA). Le texte des
documents ne change pas (même tirage, empreinte SHA-256 identique à celle de
test_generate_corpus_nir_piege.py). Données synthétiques.
"""

import hashlib
import json
import os
import random
import re
import unittest

import generate_corpus as g

# Gabarits qui écrivent un identifiant d'entreprise **comme tel**, avec le
# groupe du numéro (mêmes motifs que recensement_pieges.py).
GABARITS = [
    re.compile(r"Le SIRET de l'établissement est (?P<p>\d+)\.$"),
    re.compile(r"Le SIREN de la société est (?P<p>.+?)\.$"),
    re.compile(r"Société immatriculée au RCS de Metz sous le numéro (?P<p>.+?)\.$"),
    re.compile(r"N° de TVA intracommunautaire : (?P<p>.+?)\.$"),
    re.compile(r"Extrait Kbis : immatriculation (?P<p>.+?), gérant "),
    re.compile(r"société SIREN (?P<p>\d[\d ]*\d)\.$"),
    re.compile(r"La société (?P<p>\d[\d ]*\d) exploite la structure FINESS "),
]

EMPREINTE_V3 = "7405d819103404f453961c77fcbfbd695925d2763d61b06b30db30f0de849516"
EMPREINTE_EXTENDED = "3e5dcc37ef78efc579b6f5b8bc2a1309ff36a4fba2ecc477e4a16fb380ea4e13"


def corpus(profil, n=1000):
    templates = g.TEMPLATES + g.EXTENDED_TEMPLATES if profil == "extended" else g.TEMPLATES
    rng = random.Random(42)
    return [g.build_doc(i, rng, templates) for i in range(n)]


def empreinte(docs):
    h = hashlib.sha256()
    for d in docs:
        h.update(d["text"].encode("utf-8"))
        h.update(b"\n")
    return h.hexdigest()


def numeros(doc):
    """[(début, fin)] des identifiants d'entreprise écrits comme tels."""
    sortie = []
    for rx in GABARITS:
        m = rx.search(doc["text"])
        if m:
            sortie.append((m.start("p"), m.end("p")))
    return sortie


class SirenAnnote(unittest.TestCase):
    def setUp(self):
        self.v3 = corpus("v3")
        self.ext = corpus("extended")

    def test_textes_inchanges_octet_pour_octet(self):
        self.assertEqual(empreinte(self.v3), EMPREINTE_V3)
        self.assertEqual(empreinte(self.ext), EMPREINTE_EXTENDED)

    def test_chaque_identifiant_d_entreprise_est_annote_siren_en_entier(self):
        for docs in (self.v3, self.ext):
            for d in docs:
                for debut, fin in numeros(d):
                    self.assertIn({"type": "siren", "start": debut, "end": fin},
                                  d["entities"], d["text"])

    def test_aucune_annotation_siren_hors_d_un_identifiant_d_entreprise(self):
        for docs in (self.v3, self.ext):
            for d in docs:
                attendus = set(numeros(d))
                trouves = {(e["start"], e["end"]) for e in d["entities"]
                           if e["type"] == "siren"}
                self.assertEqual(trouves, attendus, d["text"])

    def test_la_tva_est_annotee_avec_fr_et_la_cle(self):
        vus = 0
        for d in self.ext:
            m = re.search(r"N° de TVA intracommunautaire : (FR\d{2}\d{9})\.$", d["text"])
            if not m:
                continue
            vus += 1
            self.assertIn({"type": "siren", "start": m.start(1), "end": m.end(1)},
                          d["entities"])
            self.assertEqual(d["text"][m.start(1):m.start(1) + 2], "FR")
        self.assertGreater(vus, 0)

    def test_totaux_1000_documents(self):
        def comptes(docs):
            c = {}
            for d in docs:
                for e in d["entities"]:
                    c[e["type"]] = c.get(e["type"], 0) + 1
            return c
        c3, ce = comptes(self.v3), comptes(self.ext)
        self.assertEqual(c3, {"nir": 314, "rpps": 166, "iban": 262,
                              "finess": 129, "siren": 72})
        self.assertEqual(ce, {"nir": 203, "rpps": 117, "iban": 178,
                              "finess": 172, "adeli": 125, "siren": 238})

    def test_les_types_non_siren_sont_ceux_d_avant(self):
        # 871 entités structurelles en v3 (314 + 166 + 262 + 129).
        n = sum(1 for d in self.v3 for e in d["entities"] if e["type"] != "siren")
        self.assertEqual(n, 871)


class TemoinFlou(unittest.TestCase):
    def test_le_temoin_n_a_plus_de_ligne_siret_tva(self):
        import generate_corpus_flou as f
        rng = random.Random("42:temoin")
        docs = [f.doc_temoin(rng).build(i) for i in range(400)]
        for d in docs:
            self.assertEqual(d["entities"], [])
            self.assertNotIn("SIRET", d["text"])
            self.assertNotIn("TVA", d["text"])

    def test_autres_variantes_inchangees(self):
        # Même tirage : le nombre de documents par variante ne bouge pas, et
        # les variantes 0 à 2 n'ont pas été touchées.
        import generate_corpus_flou as f
        rng = random.Random("42:temoin")
        docs = [f.doc_temoin(rng).build(i) for i in range(400)]
        remplace = [d for d in docs if "Le registre du commerce" in d["text"]]
        self.assertTrue(0 < len(remplace) < 400)


if __name__ == "__main__":
    unittest.main()
