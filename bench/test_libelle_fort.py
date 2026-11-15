"""Tests du corpus « identifiant derrière un libellé fort » et de son
scoreur (P2-194). Données synthétiques, clés calculées."""

import os
import re
import unittest

import etat_attendu
import verifie_etat
from generate_corpus import luhn_digit, nir_key
from generate_corpus_libelle_fort import (LIBELLES, NEGATIFS, VARIANTES,
                                          construit)
from score_libelle_fort import juge_positif, mesure


class Generateur(unittest.TestCase):
    def setUp(self):
        self.docs = construit(6, 42)

    def test_reproductible_a_graine_egale(self):
        self.assertEqual(self.docs, construit(6, 42))
        self.assertNotEqual(self.docs, construit(6, 7))

    def test_effectifs(self):
        pos = [d for d in self.docs if d["entities"]]
        neg = [d for d in self.docs if not d["entities"]]
        self.assertEqual(len(pos), 6 * len(LIBELLES) * len(VARIANTES))
        self.assertEqual(len(neg), 6 * len(LIBELLES) * len(NEGATIFS))
        self.assertEqual([d["id"] for d in self.docs],
                         list(range(len(self.docs))))

    def test_offsets_et_libelle_devant_l_identifiant(self):
        for d in (d for d in self.docs if d["entities"]):
            e = d["entities"][0]
            self.assertTrue(d["text"].startswith(d["libelle"]))
            avant = d["text"][len(d["libelle"]):e["start"]]
            self.assertIn(avant, (": ", " "))
            self.assertEqual(d["text"][e["end"]:], " noté au dossier.")

    def test_les_cles_sont_justes_ou_fausses_comme_annonce(self):
        for d in (d for d in self.docs if d["entities"]):
            e = d["entities"][0]
            v = re.sub(r"\s", "", d["text"][e["start"]:e["end"]])
            ocr = d["variante"] in ("ocr_zero", "ocr_un", "ocr_et_ligne_vide")
            if d["variante"] == "cle_fausse":
                self.assertFalse(self.cle_juste(d["type_id"], v), d["text"])
            elif not ocr:
                self.assertTrue(self.cle_juste(d["type_id"], v), d["text"])

    @staticmethod
    def cle_juste(type_id, v):
        if type_id == "nir":
            return len(v) == 15 and f"{nir_key(v[:13]):02d}" == v[13:]
        if type_id == "rpps" or type_id == "adeli":
            n = 11 if type_id == "rpps" else 9
            return len(v) == n and luhn_digit(v[:-1]) == v
        reordonne = v[4:] + v[:4]
        num = "".join(str(ord(c) - 55) if c.isalpha() else c
                      for c in reordonne)
        return len(v) == 27 and int(num) % 97 == 1

    def test_les_variantes_ocr_portent_bien_des_lettres(self):
        for d in (d for d in self.docs if d["entities"]):
            e = d["entities"][0]
            v = d["text"][e["start"]:e["end"]]
            if d["type_id"] == "iban":
                v = v[2:]  # le corps d'un IBAN admet déjà des lettres
            if d["variante"] in ("ocr_zero", "ocr_et_ligne_vide"):
                self.assertRegex(v, "[Oo]", d["text"])
            if d["variante"] == "ocr_un":
                self.assertRegex(v, "[lI]", d["text"])
            if d["variante"] in ("cle_juste", "cle_fausse"):
                self.assertNotRegex(v, "[OolI]", d["text"])

    def test_les_variantes_ligne_vide_en_portent_une_seule(self):
        for d in (d for d in self.docs if d["entities"]):
            e = d["entities"][0]
            v = d["text"][e["start"]:e["end"]]
            if d["variante"] in ("ligne_vide", "ocr_et_ligne_vide"):
                self.assertEqual(v.count("\n\n"), 1, d["text"])
            else:
                self.assertNotIn("\n", v)

    def test_les_negatifs_n_ont_aucune_entite_et_une_forme_nommee(self):
        for d in (d for d in self.docs if not d["entities"]):
            self.assertIn(d["temoin_negatif"], NEGATIFS)
        libelle_seul = [d for d in self.docs
                        if d.get("temoin_negatif") == "libelle_seul"]
        for d in libelle_seul:
            self.assertNotRegex(d["text"], r"\d{5}")

    def test_le_nombre_sans_libelle_n_a_pas_de_libelle_fort(self):
        for d in (d for d in self.docs
                  if d.get("temoin_negatif") == "nombre_sans_libelle"):
            self.assertNotRegex(d["text"], r"NIR|IBAN|RPPS|ADELI|SS\b")
            self.assertRegex(d["text"], r"[0-9]{3}")


class Scoreur(unittest.TestCase):
    def setUp(self):
        t = "RPPS 10000000016 noté au dossier."
        self.doc = {"id": 0, "text": t, "libelle": "RPPS", "type_id": "rpps",
                    "variante": "cle_fausse",
                    "entities": [{"type": "rpps", "start": 5, "end": 16}]}

    def pred(self, *entites):
        return {"id": 0, "entities": [
            {"type": t, "start": s, "end": e} for t, s, e in entites]}

    def test_couvert(self):
        self.assertEqual(juge_positif(self.doc, self.pred(("identifiant", 5, 16))),
                         (False, True))
        self.assertEqual(juge_positif(self.doc, self.pred(("rpps", 5, 16))),
                         (False, False))

    def test_en_clair_et_couverture_partielle(self):
        self.assertEqual(juge_positif(self.doc, self.pred())[0], True)
        self.assertEqual(
            juge_positif(self.doc, self.pred(("rpps", 7, 16)))[0], True)

    def test_les_blancs_de_l_identifiant_ne_comptent_pas(self):
        d = dict(self.doc, text="RPPS 10000 00016 noté.",
                 entities=[{"type": "rpps", "start": 5, "end": 16}])
        self.assertFalse(juge_positif(d, self.pred(
            ("rpps", 5, 10), ("rpps", 11, 16)))[0])

    def test_mesure_compte_positifs_et_negatifs(self):
        neg = {"id": 1, "text": "NIR : non communiqué.", "libelle": "NIR",
               "type_id": "nir", "entities": [],
               "temoin_negatif": "non_communique"}
        pred = [self.pred(), {"id": 1, "entities": [
            {"type": "nir", "start": 0, "end": 3}]}]
        par_case, _, _, negatifs, total = mesure([self.doc, neg], pred)
        self.assertEqual(par_case[("RPPS", "cle_fausse")]["en_clair"], 1)
        self.assertEqual(total["negatifs_masques"], 1)
        self.assertEqual(negatifs["non_communique"]["predictions"], 1)


class Plafond(unittest.TestCase):
    """`verifie_etat` fait échouer le tableau de bord si un positif repasse
    en clair, sauf défaut connu."""

    def section(self, ligne):
        return ("## identifiant derrière un libellé fort (P2-194)\n" + ligne
                + "\n")

    def test_un_positif_en_clair_hors_plafond_echoue(self):
        for ligne in ("  NIR x cle_fausse : 1 / 50 en clair, 0 au type faux",
                      "  IBAN x ocr_zero : 3 / 50 en clair, 0 au type faux"):
            p = verifie_etat.plafonds_libelle_fort(
                verifie_etat.sections(self.section(ligne).splitlines()))
            self.assertEqual(len(p), 1, ligne)
            self.assertIn("en clair (plafond 0)", p[0])

    def test_zero_en_clair_passe(self):
        p = verifie_etat.plafonds_libelle_fort(verifie_etat.sections(
            self.section("  NIR x cle_fausse : 0 / 50 en clair, 0 au type "
                         "faux").splitlines()))
        self.assertEqual(p, [])

    def test_le_defaut_connu_est_toleree_jusqu_a_son_plafond_et_pas_au_dela(self):
        (lib, var), plafond = next(iter(etat_attendu.PLAFOND_LIBELLE_FORT.items()))
        ok = f"  {lib} x {var} : {plafond} / 50 en clair, 0 au type faux"
        trop = f"  {lib} x {var} : {plafond + 1} / 50 en clair, 0 au type faux"
        self.assertEqual(verifie_etat.plafonds_libelle_fort(
            verifie_etat.sections(self.section(ok).splitlines())), [])
        self.assertEqual(len(verifie_etat.plafonds_libelle_fort(
            verifie_etat.sections(self.section(trop).splitlines()))), 1)

    def test_verifie_remonte_le_depassement(self):
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                               "etat_exemple.txt"), encoding="utf-8") as f:
            texte = f.read()
        texte = texte.replace(
            "  NIR x cle_fausse : 0 / 50 en clair",
            "  NIR x cle_fausse : 2 / 50 en clair")
        self.assertTrue(any("NIR x cle_fausse" in p
                            for p in verifie_etat.verifie(texte)))


if __name__ == "__main__":
    unittest.main()
