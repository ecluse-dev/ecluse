"""P2-280 : critères simulés du signalement « nombre dicté non reconnu »
(`score_criteres_signalement.py`). Suites synthétiques, aucune valeur réelle."""
import unittest

import score_criteres_signalement as sc


def suite(mots, avant="", couvert=False):
    return {"mots": mots, "avant": avant, "apres": ".", "couvert": couvert,
            "debut": 0, "fin": 10, "chars": 10, "jetons": mots}


class Criteres(unittest.TestCase):
    def critere(self, debut):
        return next(f for n, f in sc.CRITERES if n.startswith(debut))

    def test_mot_voisin_coupe_le_signalement(self):
        f = self.critere("9 sauf mot voisin dans les 100")
        self.assertFalse(f(suite(10, "Le code d'accès du coffre est ")))
        self.assertFalse(f(suite(10, "Composez le code de l'alarme : ")))
        self.assertTrue(f(suite(10, "Le numéro de dossier est ")))

    def test_fenetre_de_30_caracteres(self):
        long = "Le code d'accès de la grille a changé, c'est maintenant "
        f30 = self.critere("9 sauf « code »")
        f100 = self.critere("9 sauf mot voisin dans les 100")
        self.assertTrue(f30(suite(10, long)))   # « code » est trop loin
        self.assertFalse(f100(suite(10, long)))

    def test_libelle_garde_le_signalement(self):
        f = self.critere("9 sauf mot voisin (100), sauf si")
        self.assertTrue(f(suite(14, "le code IBAN fr ")))
        self.assertFalse(f(suite(14, "le code du coffre est ")))

    def test_une_suite_recouverte_n_est_jamais_signalee(self):
        self.assertFalse(sc.signale([suite(14, "", couvert=True)],
                                    lambda s: True))

    def test_forme_d_identifiant(self):
        self.assertTrue(sc.forme(suite(15)))
        self.assertTrue(sc.forme(suite(27)))
        self.assertFalse(sc.forme(suite(11)))
        self.assertFalse(sc.forme(suite(18)))


if __name__ == "__main__":
    unittest.main()
