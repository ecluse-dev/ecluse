#!/usr/bin/env python3
"""Tests de `controle_etat.py` (P2-265) : `python3 -m unittest discover -s bench`.
Sortie et ETAT.md synthétiques, comptes seulement."""

import os
import unittest

import controle_etat

ICI = os.path.dirname(os.path.abspath(__file__))

LOG = """## commit abc1234
## v3 (identifiants structurels)
Ecluse     TOTAL   100.0%  100.0%  100.0%   943     0     0
Ecluse (e)   strict        100.0%  100.0%  100.0%    72     0     0
## dictée
# en_lettres : Ecluse.redact (chemin du produit)
finess 23/129  iban 0/262  TOTAL 23/943 (2.4 %)
"""


def etat(bloc):
    return ("# historique\n| a | 92,4 % |\n\n"
            f"{controle_etat.DEBUT}\n```\n{bloc}\n```\n{controle_etat.FIN}\n")


class ControleEtat(unittest.TestCase):
    def test_bloc_propose_passe(self):
        texte = etat(controle_etat.propose(LOG).strip("`\n"))
        self.assertEqual(controle_etat.controle(texte, LOG), [])

    def test_valeur_modifiee_a_la_main_echoue(self):
        bloc = controle_etat.propose(LOG).strip("`\n").replace("23/129", "24/129")
        ecarts = controle_etat.controle(etat(bloc), LOG)
        self.assertEqual(len(ecarts), 1)
        self.assertIn("24/129", ecarts[0])
        self.assertIn("23/129", ecarts[0])  # la ligne de la sortie est montrée
        self.assertIn("ETAT.md:", ecarts[0])

    def test_espaces_ecrases(self):
        bloc = controle_etat.propose(LOG).strip("`\n")
        self.assertIn("Ecluse TOTAL 100.0% 100.0% 100.0% 943 0 0", bloc)

    def test_historique_ignore(self):
        # Le tableau d'historique contient un chiffre périmé : sans effet.
        texte = etat(controle_etat.propose(LOG).strip("`\n"))
        self.assertIn("92,4 %", texte)
        self.assertEqual(controle_etat.controle(texte, LOG), [])

    def test_section_nouvelle_dans_la_sortie_est_un_ecart(self):
        texte = etat(controle_etat.propose(LOG).strip("`\n"))
        log2 = LOG + "## nouvelle section\nligne 1 0 0\n"
        ecarts = controle_etat.controle(texte, log2)
        self.assertTrue(any("nouvelle section" in e for e in ecarts))

    def test_section_disparue_est_un_ecart(self):
        texte = etat(controle_etat.propose(LOG).strip("`\n"))
        log2 = LOG.split("## dictée")[0]
        ecarts = controle_etat.controle(texte, log2)
        self.assertTrue(any("section absente" in e for e in ecarts))

    def test_bloc_manquant_est_refuse(self):
        with self.assertRaises(ValueError):
            controle_etat.controle("# rien\n", LOG)

    def test_commit_ignore(self):
        log2 = LOG.replace("abc1234", "def5678")
        texte = etat(controle_etat.propose(LOG).strip("`\n"))
        self.assertEqual(controle_etat.controle(texte, log2), [])

    def test_ordre_des_lignes(self):
        bloc = ("## v3 (identifiants structurels)\n"
                "Ecluse (e) strict 100.0% 100.0% 100.0% 72 0 0\n"
                "Ecluse TOTAL 100.0% 100.0% 100.0% 943 0 0\n"
                "## dictée\n# en_lettres : Ecluse.redact (chemin du produit)\n"
                "finess 23/129 iban 0/262 TOTAL 23/943 (2.4 %)")
        self.assertTrue(controle_etat.controle(etat(bloc), LOG))

    def test_etat_md_du_depot_a_un_bloc(self):
        texte = open(os.path.join(ICI, "ETAT.md"), encoding="utf-8").read()
        self.assertGreater(len(controle_etat.bloc(texte)), 100)


if __name__ == "__main__":
    unittest.main()
