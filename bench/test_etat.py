#!/usr/bin/env python3
"""Tests de la vérification du tableau de bord (P2-168) :
`python3 -m unittest discover -s bench`. Données synthétiques.

`etat_exemple.txt` est une vraie sortie de `bench/etat.sh` (statistiques sur
corpus synthétiques, aucun texte). Seule sa **structure** compte ici : les
chiffres peuvent vieillir sans que ces tests changent.
"""

import os
import re
import subprocess
import sys
import tempfile
import unittest

import etat_attendu
import verifie_etat

ICI = os.path.dirname(os.path.abspath(__file__))
EXEMPLE = open(os.path.join(ICI, "etat_exemple.txt"), encoding="utf-8").read()


def sans_lignes(texte, motif, section=None):
    """Le texte sans les lignes qui satisfont `motif` (dans `section`)."""
    sortie, courant = [], None
    for l in texte.splitlines():
        if l.startswith("## "):
            courant = l
        if re.search(motif, l) and (section is None
                                    or (courant or "").startswith(section)):
            continue
        sortie.append(l)
    return "\n".join(sortie) + "\n"


class VerificationTest(unittest.TestCase):
    def test_la_sortie_d_exemple_passe(self):
        self.assertEqual(verifie_etat.verifie(EXEMPLE), [])

    def test_chaque_motif_attendu_est_necessaire(self):
        # Retirer toutes les lignes d'un motif dans sa section doit être vu.
        for prefixe, regles in etat_attendu.ATTENDU:
            for motif, minimum, _ in regles:
                with self.subTest(section=prefixe, motif=motif):
                    abime = sans_lignes(EXEMPLE, motif, prefixe)
                    problemes = verifie_etat.verifie(abime)
                    self.assertTrue(
                        any(prefixe in p and (f"/{motif}/" in p
                                              or "section manquante" in p)
                            for p in problemes),
                        f"retirer /{motif}/ de {prefixe} n'est pas détecté")

    def test_une_section_vide_est_detectee(self):
        # Le défaut d'origine : un filtre qui ne trouve plus rien (« extractions »
        # cherché alors que le score écrit « Extractions »).
        abime = sans_lignes(EXEMPLE, r"Extractions", "## quasi-identifiants")
        problemes = verifie_etat.verifie(abime)
        self.assertTrue(any("Extractions" in p for p in problemes), problemes)

    def test_une_section_entiere_manquante_est_detectee(self):
        abime = "\n".join(
            l for l in EXEMPLE.splitlines()
            if not l.startswith("## pathologies")) + "\n"
        # Les lignes de la section restent mais sans titre : elles passent dans
        # la section précédente ; la section attendue manque.
        problemes = verifie_etat.verifie(abime)
        self.assertTrue(any("section manquante : ## pathologies" in p
                            for p in problemes), problemes)

    def test_une_ligne_echec_est_une_erreur(self):
        for ligne in ("ÉCHEC : dossiers adversarial, Ecluse.redact : code 1",
                      "section vide : QI temoin, score"):
            with self.subTest(ligne=ligne):
                problemes = verifie_etat.verifie(EXEMPLE + ligne + "\n")
                self.assertTrue(any(ligne in p for p in problemes), problemes)

    def test_un_avertissement_n_est_pas_une_erreur(self):
        texte = EXEMPLE + "AVERTISSEMENT : types d'entité absents : identifiant\n"
        self.assertEqual(verifie_etat.verifie(texte), [])

    def test_ligne_de_cohérence_des_noms_et_temoin_de_mise_en_page(self):
        # Deux lignes annoncées par ETAT.md que l'ancien script n'imprimait pas.
        self.assertRegex(EXEMPLE, r"(?m)^    nom +\d+ / +\d+")
        mise_en_page = EXEMPLE[EXEMPLE.index("## mise en page"):]
        self.assertGreaterEqual(
            len(re.findall(r"(?m)^  entites predites \d+$", mise_en_page)), 2)


class LigneDeCommandeTest(unittest.TestCase):
    def lance(self, contenu):
        with tempfile.NamedTemporaryFile(
                "w", suffix=".log", delete=False, encoding="utf-8") as f:
            f.write(contenu)
        try:
            return subprocess.run(
                [sys.executable, os.path.join(ICI, "verifie_etat.py"), f.name],
                capture_output=True, text=True, cwd=ICI)
        finally:
            os.unlink(f.name)

    def test_code_zero_sur_une_sortie_saine(self):
        r = self.lance(EXEMPLE)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_code_un_et_motif_nomme_sur_un_trou(self):
        r = self.lance(sans_lignes(EXEMPLE, r"Extractions"))
        self.assertEqual(r.returncode, 1)
        self.assertIn("MANQUE", r.stdout)
        self.assertIn("Extractions", r.stdout)

    def test_fichier_absent_est_un_echec_explicite(self):
        r = subprocess.run(
            [sys.executable, os.path.join(ICI, "verifie_etat.py"),
             "/chemin/inexistant.log"], capture_output=True, text=True, cwd=ICI)
        self.assertEqual(r.returncode, 66)
        self.assertIn("ÉCHEC", r.stdout)


if __name__ == "__main__":
    unittest.main()
