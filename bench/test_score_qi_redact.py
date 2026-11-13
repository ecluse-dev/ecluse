#!/usr/bin/env python3
"""Tests de `score_qi_redact.py` (P2-175, premier volet).

Corpus et prédictions miniatures en mémoire, patronymes synthétiques tirés
de `generate_corpus_flou.NOMS` (aucun nom réel).
"""

import unittest

from score_qi_redact import couvert, fuites


class TestCouvert(unittest.TestCase):
    def test_intervalle_couvrant(self):
        self.assertTrue(couvert(5, 13, [(0, 20)]))

    def test_intervalle_partiel_ne_couvre_pas(self):
        self.assertFalse(couvert(5, 13, [(0, 10)]))

    def test_aucun_intervalle(self):
        self.assertFalse(couvert(5, 13, []))


class TestFuites(unittest.TestCase):
    def test_patronyme_masque_par_civilite_pas_de_fuite(self):
        # « Mme Chevrier » : NameDetector masque civilité + patronyme.
        civilite = 'Mme Chevrier'
        texte = f'{civilite} réside à Dole.'
        corpus = [{'id': 0, 'text': texte}]
        pred = [{
            'id': 0,
            'entities': [{'type': 'nom', 'start': 0, 'end': len(civilite)}],
        }]
        self.assertEqual(fuites(corpus, pred), [])

    def test_patronyme_derriere_un_metier_sans_civilite_fuite(self):
        # Le défaut mesuré par la sonde : aucune civilité, le détecteur de
        # noms ne déclenche pas, le patronyme reste en clair.
        texte = "L'infirmière Chevrier a transmis le dossier."
        corpus = [{'id': 0, 'text': texte}]
        pred = [{'id': 0, 'entities': []}]
        resultat = fuites(corpus, pred)
        self.assertEqual(len(resultat), 1)
        self.assertEqual(resultat[0][0], 0)
        self.assertIn('Chevrier', resultat[0][1])

    def test_document_refuse_est_ignore(self):
        # Un document refusé (tableau ambigu) ne part pas : pas de fuite à
        # chercher dans un texte qui n'a jamais quitté le sas.
        texte = "L'infirmière Chevrier a transmis le dossier."
        corpus = [{'id': 0, 'text': texte}]
        pred = [{'id': 0, 'entities': [], 'refuse': True}]
        self.assertEqual(fuites(corpus, pred), [])

    def test_document_sans_prediction_est_ignore(self):
        corpus = [{'id': 0, 'text': "L'infirmière Chevrier."}]
        self.assertEqual(fuites(corpus, []), [])

    def test_deux_patronymes_un_seul_masque(self):
        civilite = 'Le Dr Chevrier'
        texte = f"{civilite} remplace l'infirmière Marchand."
        corpus = [{'id': 0, 'text': texte}]
        # « Le Dr Chevrier » masqué ; « Marchand » pas couvert.
        pred = [{
            'id': 0,
            'entities': [{'type': 'nom', 'start': 0, 'end': len(civilite)}],
        }]
        resultat = fuites(corpus, pred)
        self.assertEqual(len(resultat), 1)
        self.assertEqual(resultat[0][1], ['Marchand'])


if __name__ == '__main__':
    unittest.main()
