"""Tests de `resume_temoins_homonymes.py` (P2-320) : groupes, seuil, échecs."""

import unittest

from resume_temoins_homonymes import groupe, resume

BASE = [
    "corpus | documents | avertis | part",
    "bench/corpus.jsonl | 1000 | 0 | 0.00 %",
    "bench/flou/corpus_flou_fauxamis.jsonl | 400 | 0 | 0.00 %",
    "bench/flou/corpus_flou_realiste_minuscules.jsonl | 400 | 9 | 2.25 %",
    "bench/transcrit/corpus_transcrit_zero_o.jsonl | 1000 | 0 | 0.00 %",
    "/tmp/w/tournures_sans_nom.jsonl | 400 | 8 | 2.00 %",
    "/tmp/w/tournures_personne.jsonl | 480 | 36 | 7.50 %",
]


class ResumeTest(unittest.TestCase):
    def test_groupes(self):
        self.assertEqual(groupe("bench/flou/corpus_flou_realiste_phrase.jsonl"), "minuscules")
        self.assertEqual(groupe("bench/flou/corpus_flou_realiste_majuscules.jsonl"), "ordinaire")
        self.assertEqual(groupe("/tmp/x/tournures_personne.jsonl"), "personne")
        self.assertEqual(groupe("/tmp/x/tournures_sans_nom.jsonl"), "tournures")
        self.assertEqual(groupe("bench/transcrit/corpus_transcrit_en_lettres.jsonl"), "minuscules")

    def test_etat_normal_sans_echec(self):
        s = resume(BASE)
        self.assertEqual(len(s), 4)
        self.assertFalse(any(l.startswith("ÉCHEC") for l in s))
        self.assertTrue(s[0].endswith("casse ordinaire : 2 corpus, 1400 documents, 0 avertis, pire 0.00 %"), s[0])
        self.assertIn("pire 2.25 % (corpus_flou_realiste_minuscules)", s[1])
        self.assertIn("tournures sans nom : 8 / 400 (2.00 %)", s[2])
        # tournures_personne dépasse 5 % mais n'est pas un témoin : pas d'échec.
        self.assertIn("sans seuil) : 36 / 480 (7.50 %)", s[3])

    def test_depassement_ordinaire_est_un_echec(self):
        bad = [l.replace("fauxamis.jsonl | 400 | 0", "fauxamis.jsonl | 400 | 21") for l in BASE]
        self.assertTrue(any(l.startswith("ÉCHEC") and "corpus_flou_fauxamis" in l for l in resume(bad)))

    def test_seuil_exact_passe_et_au_dessus_echoue(self):
        ok = [l.replace("sans_nom.jsonl | 400 | 8", "sans_nom.jsonl | 400 | 20") for l in BASE]
        self.assertFalse(any(l.startswith("ÉCHEC") for l in resume(ok)))  # 5,00 %
        bad = [l.replace("sans_nom.jsonl | 400 | 8", "sans_nom.jsonl | 400 | 21") for l in BASE]
        self.assertTrue(any(l.startswith("ÉCHEC") for l in resume(bad)))

    def test_depassement_minuscules(self):
        bad = [l.replace("minuscules.jsonl | 400 | 9", "minuscules.jsonl | 400 | 30") for l in BASE]
        self.assertTrue(any(l.startswith("ÉCHEC") and "minuscules" in l for l in resume(bad)))

    def test_groupe_vide_et_echec_repris(self):
        s = resume(["ÉCHEC : bench/flou/corpus_x.jsonl"] + BASE[:2])
        self.assertEqual(s[0], "ÉCHEC : bench/flou/corpus_x.jsonl")
        self.assertTrue(any("aucun corpus mesuré" in l for l in s))
        self.assertTrue(any("absent de la mesure" in l for l in s))

    def test_un_corpus_present_deux_fois_est_compte_une_fois(self):
        double = BASE + ["bench/flou/corpus_tournures_sans_nom.jsonl | 400 | 8 | 2.00 %"]
        self.assertEqual(resume(double), resume(BASE))

    def test_aucune_valeur_de_texte(self):
        # La seule entrée est un tableau de comptes ; la sortie n'en cite que.
        for l in resume(BASE):
            self.assertNotRegex(l, r"\d{13}")


if __name__ == "__main__":
    unittest.main()
