#!/usr/bin/env python3
"""Tests du corpus « CEDEX apres une commune longue » et de son scoreur
(P2-178) : `python3 -m unittest discover -s bench`. Noms de communes du
referentiel public, reste synthetique."""

import os
import re
import unittest

import generate_corpus_cedex as gc
import score_cedex as sc

ICI = os.path.dirname(os.path.abspath(__file__))
COMMUNES = os.path.join(ICI, "..", "packages", "ecluse_reference", "assets",
                        "geo_communes.csv.gz")


class CorpusTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.par_mots = gc.lit_communes(COMMUNES)
        cls.docs = gc.construit(cls.par_mots, 5, 42)

    def test_reproductible_a_graine_egale(self):
        self.assertEqual(self.docs, gc.construit(self.par_mots, 5, 42))
        self.assertNotEqual(self.docs, gc.construit(self.par_mots, 5, 43))

    def test_nombre_de_mots_compte_sur_la_forme_postale(self):
        for mots, communes in self.par_mots.items():
            for _, _, norm, _ in communes[:50]:
                self.assertEqual(len(norm.split()), mots)
        self.assertEqual(min(self.par_mots), 1)
        self.assertGreaterEqual(max(self.par_mots), 7)

    def test_chaque_commune_sous_les_24_combinaisons(self):
        par_commune = {}
        for d in self.docs:
            par_commune.setdefault((d["mots"], d["com"]), set()).add(
                (d["ecriture"], d["cedex"], d["voie"]))
        for combinaisons in par_commune.values():
            self.assertEqual(len(combinaisons), 24)
        # Cinq communes par longueur, ou toutes s'il y en a moins.
        for mots, communes in self.par_mots.items():
            tirees = sum(1 for (m, _) in par_commune if m == mots)
            self.assertEqual(tirees, min(5, len(communes)))

    def test_offsets_exacts(self):
        for d in self.docs:
            t = d["text"]
            e = d["entities"][0]
            self.assertEqual(e["type"], "adresse")
            adresse = t[e["start"]:e["end"]]
            commune = t[slice(*d["parties"]["commune"])]
            # Le code postal precede la commune, dans l'adresse annotee.
            self.assertRegex(
                t[:d["parties"]["commune"][0]], r"(?<!\d)\d{5} $", t)
            self.assertIn(commune, adresse)
            self.assertNotIn("\n", adresse)
            if d["cedex"] == "sans":
                self.assertIsNone(d["parties"]["cedex"])
                self.assertIsNone(d["parties"]["numero"])
                self.assertTrue(adresse.endswith(commune))
            else:
                self.assertEqual(
                    t[slice(*d["parties"]["cedex"])].upper(), "CEDEX")
                self.assertRegex(t[slice(*d["parties"]["numero"])],
                                 r"^\d{1,2}$")
                self.assertEqual(d["parties"]["numero"][1], e["end"])
            if d["voie"] == "avec":
                self.assertRegex(adresse, r"^\d{1,2} [a-z]+ ")
            else:
                self.assertRegex(adresse, r"^\d{5} ")
                self.assertEqual(t[e["start"] - 1], "\n")

    def test_ecritures(self):
        for d in self.docs:
            commune = d["text"][slice(*d["parties"]["commune"])]
            if d["ecriture"] == "postale":
                self.assertRegex(commune, r"^[A-Z0-9 ()]+$", commune)
            elif d["ecriture"] == "capitales_tirets":
                self.assertEqual(commune, commune.upper())
            elif d["ecriture"] == "libelle_espaces":
                self.assertNotIn("-", commune.replace(" - ", " "))

    def test_balayage_toutes_les_communes_une_fois_par_ecriture(self):
        # Sur un extrait du referentiel : le balayage complet est long.
        extrait = {m: c[:30] for m, c in self.par_mots.items()}
        docs = gc.construit(extrait, 40, 42, balayage=True)
        communes = sum(len(c) for c in extrait.values())
        self.assertEqual(len(docs), communes * len(gc.ECRITURES))
        self.assertEqual({d["cedex"] for d in docs}, {"CEDEX n"})
        self.assertEqual({d["voie"] for d in docs}, {"sans"})


def doc(commune, cedex=" CEDEX 9"):
    """Document de test : « 12345 <commune><cedex> » apres une ligne."""
    avant = "Courrier :\n12345 "
    texte = avant + commune + cedex + "\nMerci."
    debut = len(avant) - 6
    c0 = len(avant)
    c1 = c0 + len(commune)
    parties = {"commune": [c0, c1], "cedex": None, "numero": None}
    if cedex:
        parties["cedex"] = [c1 + 1, c1 + 6]
        parties["numero"] = [c1 + 7, c1 + 7 + len(cedex) - 7]
    return {"id": 0, "text": texte, "com": "00000",
            "entities": [{"type": "adresse", "start": debut,
                          "end": c1 + len(cedex)}],
            "parties": parties, "mots": len(commune.split()),
            "ecriture": "libelle", "cedex": "CEDEX n" if cedex else "sans",
            "voie": "sans"}


def pred_jusqu_a(d, fin_relative):
    """Prediction qui couvre l'adresse jusqu'a `fin_relative` caracteres de la
    commune (None : toute l'adresse)."""
    e = d["entities"][0]
    fin = (e["end"] if fin_relative is None
           else d["parties"]["commune"][0] + fin_relative)
    return {"id": 0, "entities": [{"type": "adresse", "start": e["start"],
                                   "end": fin}]}


def couverts(pred):
    c = set()
    for p in pred["entities"]:
        c.update(range(p["start"], p["end"]))
    return c


class ScoreTest(unittest.TestCase):
    def test_adresse_entierement_couverte(self):
        d = doc("Vesoul")
        utiles, clair, parties = sc.juge(d, pred_jusqu_a(d, None))
        self.assertEqual(clair, 0)
        self.assertEqual(utiles, len("12345VesoulCEDEX9"))
        self.assertEqual(parties, {"commune": False, "cedex": False,
                                   "numero": False})
        self.assertIsNone(sc.cause(d, couverts(pred_jusqu_a(d, None))))

    def test_numero_seul_en_clair(self):
        d = doc("Vesoul")
        p = pred_jusqu_a(d, len("Vesoul CEDEX"))
        utiles, clair, parties = sc.juge(d, p)
        self.assertEqual(clair, 1)
        self.assertEqual(parties, {"commune": False, "cedex": False,
                                   "numero": True})
        self.assertIsNone(sc.cause(d, couverts(p)))

    def test_causes(self):
        for commune, fin, attendu in [
            ("Le Mémont", len("Le"), "faux titre"),
            ("Saint Martin sur le Pré", len("Saint Martin"), "faux titre"),
            ("Moliets et Maa", len("Moliets"), "liaison absente : et"),
            ("Norroy lès Pont à Mousson", len("Norroy lès Pont"),
             "liaison absente : à"),
            ("SAINT MICHEL DE SAINT GEOIRS", len("SAINT MICHEL DE SAINT"),
             "longueur"),
            ("Bors (Canton de Tude)", len("Bors"), "ponctuation"),
            ("Annœullin", len("Ann"), "milieu de mot"),
            ("Le Mans", len("Le"), "autre"),
        ]:
            d = doc(commune)
            self.assertEqual(sc.cause(d, couverts(pred_jusqu_a(d, fin))),
                             attendu, commune)

    def test_faux_titre(self):
        for mot in ["Mémont", "Mée-sur-Seine", "Pré", "MÉMONT", "d'Mé"]:
            self.assertTrue(sc.faux_titre(mot), mot)
        for mot in ["Mans", "Metz", "Prat", "Dreux", "Memont", "M"]:
            self.assertFalse(sc.faux_titre(mot), mot)

    def test_compte_par_axe_et_refus(self):
        d1 = doc("Vesoul")
        d2 = dict(doc("Moliets et Maa"), id=1)
        d3 = dict(doc("Dole"), id=2)
        preds = {0: pred_jusqu_a(d1, None),
                 1: dict(pred_jusqu_a(d2, len("Moliets")), id=1),
                 2: {"id": 2, "entities": [], "refuse": True}}
        stats, refus, exemples, causes, communes = sc.compte(
            [d1, d2, d3], preds)
        self.assertEqual(refus, 1)
        self.assertEqual(stats[("mots", 1)]["adresses"], 1)
        self.assertEqual(stats[("mots", 3)]["en_defaut"], 1)
        self.assertEqual(stats[("mots", 3)]["commune"], 1)
        self.assertEqual(stats[("mots", 3)]["numero"], 1)
        self.assertEqual(causes, {"liaison absente : et": 1})
        self.assertEqual(len(exemples[3]), 1)

    def test_exemple_masque_sans_valeur_detectee(self):
        d = doc("Moliets et Maa")
        texte = sc.masque(d, pred_jusqu_a(d, len("Moliets")))
        self.assertNotIn("Moliets", texte)
        self.assertNotIn("12345", texte)
        self.assertTrue(re.search(r"\[ADRESSE\] et Maa CEDEX 9", texte))


if __name__ == "__main__":
    unittest.main()
