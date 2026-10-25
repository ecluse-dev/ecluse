#!/usr/bin/env python3
"""Tests du generateur et du scoreur de dossiers : `python3 -m unittest
discover -s bench` (depuis la racine). Donnees synthetiques, aucune lecture
reseau."""

import re
import unittest

import generate_corpus_dossiers as gen
import score_dossiers as sc

NOMS_CORPUS = ("realiste", "adversarial", "temoin")


def corpus(nom, n=300, seed=42):
    return gen.construit(nom, n, seed)


def par_id(docs):
    return {d["id"]: d for d in docs}


def preds_parfaits(docs, jeton_de):
    """Predictions qui detectent toutes les mentions ; `jeton_de(doc, ent)`
    donne le jeton."""
    return {
        d["id"]: {
            "mentions": [{"type": e["type"], "start": e["start"],
                          "end": e["end"], "jeton": jeton_de(d, e)}
                         for e in d["entities"]],
            "restaure": True,
        } for d in docs}


def jeton_unique_par_identite():
    """Un jeton par identite, stable dans tout le corpus : cas ideal."""
    attribues = {}

    def jeton(d, e):
        n = attribues.setdefault(e["identite"], len(attribues) + 1)
        return f"[{e['type'].upper()}_{n}]"
    return jeton


class GenerateurTest(unittest.TestCase):
    def test_reproductible_par_graine(self):
        for nom in NOMS_CORPUS:
            self.assertEqual(corpus(nom, 80, 7), corpus(nom, 80, 7))

    def test_graines_differentes_donnent_des_corpus_differents(self):
        self.assertNotEqual(corpus("realiste", 80, 1), corpus("realiste", 80, 2))

    def test_ajouter_des_documents_ne_decale_pas_le_debut(self):
        for nom in NOMS_CORPUS:
            court, long_ = corpus(nom, 60), corpus(nom, 120)
            self.assertEqual(court, long_[:len(court)])

    def test_au_plus_n_documents_et_ids_consecutifs(self):
        for nom in NOMS_CORPUS:
            docs = corpus(nom, 100)
            self.assertLessEqual(len(docs), 100)
            self.assertGreater(len(docs), 90)
            self.assertEqual([d["id"] for d in docs], list(range(len(docs))))

    def test_dossiers_de_3_a_6_documents_et_rangs_croissants(self):
        for nom in NOMS_CORPUS:
            tailles = {}
            for d in corpus(nom):
                tailles.setdefault(d["dossier"], []).append(d["rang"])
            for rangs in tailles.values():
                self.assertEqual(rangs, list(range(len(rangs))))
                self.assertTrue(3 <= len(rangs) <= 6, (nom, rangs))

    def test_offsets_exacts_et_types_connus(self):
        for nom in NOMS_CORPUS:
            for d in corpus(nom):
                for e in d["entities"]:
                    self.assertIn(e["type"], {"nom", "email", "telephone"})
                    m = d["text"][e["start"]:e["end"]]
                    self.assertTrue(m.strip())
                    self.assertEqual(m, m.strip())
                    if e["type"] == "email":
                        self.assertRegex(m, r"^[^@ ]+@(?:[a-z]+\.)?example\.(?:fr|com)$")

    def test_aucun_chevauchement_dans_un_document(self):
        for nom in NOMS_CORPUS:
            for d in corpus(nom):
                es = sorted(d["entities"], key=lambda e: e["start"])
                for a, b in zip(es, es[1:]):
                    self.assertLessEqual(a["end"], b["start"])

    def test_identite_unique_par_valeur_pour_email_et_telephone(self):
        for nom in NOMS_CORPUS:
            vues = {}
            for d in corpus(nom):
                for e in d["entities"]:
                    if e["type"] == "nom":
                        continue
                    valeur = d["text"][e["start"]:e["end"]]
                    self.assertIn(e["identite"], (f"email:{valeur}", f"tel:{valeur}"))
                    vues.setdefault(e["identite"], valeur)

    def test_une_identite_nom_ne_change_pas_de_patronyme(self):
        # Un meme pid garde le meme patronyme dans tout le corpus.
        for nom in NOMS_CORPUS:
            patronyme = {}
            for d in corpus(nom):
                for e in d["entities"]:
                    if e["type"] != "nom" or e.get("ambigue"):
                        continue
                    mot = d["text"][e["start"]:e["end"]].split()[-1]
                    self.assertEqual(patronyme.setdefault(e["identite"], mot), mot)

    def test_realiste_aucune_ambiguite_et_pas_de_personne_partagee(self):
        docs = corpus("realiste")
        self.assertFalse(any(e.get("ambigue") for d in docs for e in d["entities"]))
        dossiers_de = {}
        for d in docs:
            for e in d["entities"]:
                if e["type"] == "nom":
                    dossiers_de.setdefault(e["identite"], set()).add(d["dossier"])
        self.assertTrue(all(len(s) == 1 for s in dossiers_de.values()))

    def test_realiste_premiere_mention_complete(self):
        # Le premier document d'un dossier nomme chaque personne en entier.
        for d in corpus("realiste"):
            if d["rang"] != 0:
                continue
            for e in d["entities"]:
                if e["type"] == "nom":
                    self.assertGreaterEqual(
                        len(d["text"][e["start"]:e["end"]].split()), 3)

    def test_temoin_aucune_valeur_partagee_entre_dossiers(self):
        dossiers_de = {}
        for d in corpus("temoin", 400):
            for e in d["entities"]:
                dossiers_de.setdefault(e["identite"], set()).add(d["dossier"])
        self.assertTrue(all(len(s) == 1 for s in dossiers_de.values()))
        # Nom + prenom jamais partages non plus (au-dela du pid).
        couples = {}
        for d in corpus("temoin", 400):
            for e in d["entities"]:
                if e["type"] == "nom" and e["identite"] not in couples:
                    couples[e["identite"]] = d["text"][e["start"]:e["end"]].split(" ", 1)[1]
        self.assertEqual(len(couples), len(set(couples.values())))

    def test_adversarial_couvre_les_pieges(self):
        docs = corpus("adversarial", 400)
        texte = "\n".join(d["text"] for d in docs)
        self.assertIn("[NOM_1]", texte)  # jeton litteral
        self.assertTrue(any(e.get("ambigue") for d in docs for e in d["entities"]))
        dossiers_de = {}
        for d in docs:
            for e in d["entities"]:
                dossiers_de.setdefault(e["identite"], set()).add(d["dossier"])
        self.assertTrue(any(len(s) > 1 for k, s in dossiers_de.items() if k))
        for patronyme in ("Verdier", "Petit", "Berger", "Loyer"):
            self.assertIn(patronyme, texte)
        # Repetition d'e-mail et de telephone d'un document a l'autre.
        emails = [e["identite"] for d in docs for e in d["entities"]
                  if e["type"] == "email"]
        self.assertLess(len(set(emails)), len(emails))

    def test_aucune_donnee_reelle(self):
        # Seuls domaines de test et plages de telephone de fiction.
        for nom in NOMS_CORPUS:
            for d in corpus(nom):
                for m in re.findall(r"@([\w.]+)", d["text"]):
                    self.assertTrue(m.endswith(("example.fr", "example.com")), m)
                for e in d["entities"]:
                    if e["type"] == "telephone":
                        chiffres = re.sub(r"\D", "", d["text"][e["start"]:e["end"]])
                        self.assertTrue(chiffres.startswith(
                            ("0199", "0261", "0353", "0465", "0536", "0639", "0700")))


class ScoreurTest(unittest.TestCase):
    def mesure(self, docs, preds):
        return sc.mesure(par_id(docs), preds)

    def test_cas_ideal_coherence_totale_sans_collision(self):
        docs = corpus("realiste", 120)
        m = self.mesure(docs, preds_parfaits(docs, jeton_unique_par_identite()))
        a, b = m["coherence"]["tous"]
        self.assertEqual(a, b)
        self.assertGreater(b, 0)
        self.assertEqual(m["collisions"][0], 0)
        self.assertEqual(m["fausses_fusions"][0], 0)
        self.assertEqual(m["non_restaures"][0], 0)
        self.assertEqual(m["non_detectees"], {})

    def test_numerotation_par_document_cree_des_collisions(self):
        # Cas du moteur sans etat : la n-ieme personne distincte d'un
        # document recoit [NOM_n], d'un document a l'autre.
        docs = corpus("adversarial", 200)

        def numerote(d, e):
            ordre = []
            for x in d["entities"]:
                cle = (x["type"], x["identite"])
                if cle not in ordre:
                    ordre.append(cle)
            return f"[{e['type'].upper()}_{ordre.index((e['type'], e['identite'])) + 1}]"

        m = self.mesure(docs, preds_parfaits(docs, numerote))
        self.assertGreater(m["collisions"][0], 0)

    def test_fausse_fusion_dans_un_document(self):
        docs = [{"id": 0, "dossier": 0, "rang": 0, "text": "A et B",
                 "entities": [
                     {"type": "nom", "start": 0, "end": 1, "identite": "p1"},
                     {"type": "nom", "start": 5, "end": 6, "identite": "p2"}]}]
        preds = preds_parfaits(docs, lambda d, e: "[NOM_1]")
        m = self.mesure(docs, preds)
        self.assertEqual(m["fausses_fusions"], (1, 1))
        self.assertEqual(m["collisions"], (1, 1))

    def test_identite_a_deux_jetons_est_incoherente(self):
        docs = [
            {"id": i, "dossier": 0, "rang": i, "text": "A",
             "entities": [{"type": "nom", "start": 0, "end": 1, "identite": "p1"}]}
            for i in range(2)]
        preds = preds_parfaits(docs, lambda d, e: f"[NOM_{d['id'] + 1}]")
        m = self.mesure(docs, preds)
        self.assertEqual(m["coherence"]["tous"], (0, 1))

    def test_mention_non_detectee_exclue_et_comptee(self):
        docs = [{"id": 0, "dossier": 0, "rang": 0, "text": "A A",
                 "entities": [
                     {"type": "nom", "start": 0, "end": 1, "identite": "p1"},
                     {"type": "nom", "start": 2, "end": 3, "identite": "p1"}]}]
        preds = {0: {"mentions": [{"type": "nom", "start": 0, "end": 1,
                                   "jeton": "[NOM_1]"}], "restaure": True}}
        m = self.mesure(docs, preds)
        self.assertEqual(m["non_detectees"], {"nom": 1})
        self.assertNotIn("tous", m["coherence"])  # une seule mention restante

    def test_type_different_ne_compte_pas_comme_detection(self):
        docs = [{"id": 0, "dossier": 0, "rang": 0, "text": "A",
                 "entities": [{"type": "nom", "start": 0, "end": 1, "identite": "p1"}]}]
        preds = {0: {"mentions": [{"type": "email", "start": 0, "end": 1,
                                   "jeton": "[EMAIL_1]"}], "restaure": True}}
        self.assertEqual(self.mesure(docs, preds)["non_detectees"], {"nom": 1})

    def test_mention_ambigue_a_part(self):
        docs = [{"id": 0, "dossier": 0, "rang": 0, "text": "A B",
                 "entities": [
                     {"type": "nom", "start": 0, "end": 1, "identite": "p1"},
                     {"type": "nom", "start": 2, "end": 3, "identite": None,
                      "ambigue": True}]}]
        preds = preds_parfaits(docs, lambda d, e: "[NOM_1]")
        m = self.mesure(docs, preds)
        self.assertEqual(m["ambigues"], {"total": 1, "detectees": 1,
                                         "fusionnees": 1,
                                         "fusionnees_dossier": 1})
        self.assertEqual(m["collisions"], (0, 1))  # l'ambigue n'entre pas

    def test_mention_ambigue_fusionnee_avec_un_autre_document_du_dossier(self):
        docs = [
            {"id": 0, "dossier": 0, "rang": 0, "text": "A",
             "entities": [{"type": "nom", "start": 0, "end": 1,
                           "identite": "p1"}]},
            {"id": 1, "dossier": 0, "rang": 1, "text": "B",
             "entities": [{"type": "nom", "start": 0, "end": 1,
                           "identite": None, "ambigue": True}]}]
        preds = preds_parfaits(docs, lambda d, e: "[NOM_1]")
        am = self.mesure(docs, preds)["ambigues"]
        self.assertEqual((am["fusionnees"], am["fusionnees_dossier"]), (0, 1))
        distinct = preds_parfaits(docs, lambda d, e: f"[NOM_{d['id'] + 1}]")
        self.assertEqual(self.mesure(docs, distinct)["ambigues"]
                         ["fusionnees_dossier"], 0)

    def test_restauration_non_identique(self):
        docs = [{"id": 0, "dossier": 0, "rang": 0, "text": "", "entities": []}]
        m = self.mesure(docs, {0: {"mentions": [], "restaure": False}})
        self.assertEqual(m["non_restaures"], (1, 1))

    def test_recoupement_meme_jeton_et_reference(self):
        def doc(i, dossier, ident):
            return {"id": i, "dossier": dossier, "rang": 0, "text": "A",
                    "entities": [{"type": "nom", "start": 0, "end": 1,
                                  "identite": ident}]}
        docs = [doc(0, 0, "p1"), doc(1, 1, "p1"), doc(2, 2, "p2")]
        preds = preds_parfaits(docs, lambda d, e: "[NOM_1]")
        r = self.mesure(docs, preds)["recoupement"]
        self.assertEqual(r["identites_partagees"], 1)
        self.assertEqual((r["paires"], r["meme_jeton"]), (1, 1))
        # Paires d'identites distinctes de dossiers distincts : (p1@0,p2@2),
        # (p1@1,p2@2) ; toutes au meme jeton.
        self.assertEqual((r["reference_paires"], r["reference_meme_jeton"]), (2, 2))

    def test_temoin_sans_recoupement(self):
        docs = corpus("temoin", 120)
        m = self.mesure(docs, preds_parfaits(docs, jeton_unique_par_identite()))
        self.assertEqual(m["recoupement"]["paires"], 0)

    def test_predictions_vides_ne_plantent_pas(self):
        docs = corpus("adversarial", 60)
        m = self.mesure(docs, {})
        self.assertGreater(sum(m["non_detectees"].values()), 0)
        self.assertEqual(m["collisions"][0], 0)


if __name__ == "__main__":
    unittest.main()
