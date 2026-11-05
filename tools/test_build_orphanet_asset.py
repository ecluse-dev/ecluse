"""Tests de `build_orphanet_asset.py` sur un pack synthetique minimal.

Aucune donnee Orphanet n'est versionnee ici : les entites sont inventees,
seule la structure XML du pack est reprise.

    python3 -m unittest tools/test_build_orphanet_asset.py
"""

import gzip
import io
import os
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, os.path.dirname(__file__))
import build_orphanet_asset as b  # noqa: E402

LICENCE = ("<Availability><Licence><ShortIdentifier>{}</ShortIdentifier>"
           "</Licence></Availability>")


def _lin(licence="CC-BY-4.0"):
    return ("<JDBOR ExtractionDate=\"2026-01-01\">" + LICENCE.format(licence) +
            "<DisorderList>"
            "<Disorder><OrphaCode>10</OrphaCode><DisorderDisorderAssociationList>"
            "<DisorderDisorderAssociation><TargetDisorder><OrphaCode>1</OrphaCode>"
            "<Name lang=\"fr\">Maladie inventee rare</Name></TargetDisorder>"
            "</DisorderDisorderAssociation></DisorderDisorderAssociationList>"
            "</Disorder>"
            "<Disorder><OrphaCode>20</OrphaCode><DisorderDisorderAssociationList>"
            "<DisorderDisorderAssociation><TargetDisorder><OrphaCode>1</OrphaCode>"
            "<Name lang=\"fr\">Maladie inventee rare</Name></TargetDisorder>"
            "</DisorderDisorderAssociation></DisorderDisorderAssociationList>"
            "</Disorder>"
            "</DisorderList></JDBOR>")


def _nom(licence="CC-BY-4.0"):
    def ent(code, nom, *syn):
        s = "".join(f"<Synonym lang=\"fr\">{x}</Synonym>" for x in syn)
        return (f"<Disorder><OrphaCode>{code}</OrphaCode>"
                f"<Name lang=\"fr\">{nom}</Name><SynonymList>{s}</SynonymList>"
                "</Disorder>")
    return ("<JDBOR ExtractionDate=\"2026-01-01\">" + LICENCE.format(licence) +
            "<DisorderList>" +
            ent("20", "Syndrome de Zorglub", "SZ", "syndrome de zorglub",
                "Zorglubose") +
            ent("10", "Maladie de Pifou", "SLA", "ALD") +
            ent("99", "OBSOLETE : Maladie retiree") +
            "</DisorderList></JDBOR>")


def _pack(dossier, lin=None, nom=None, nom_lin="ORPHAlinearisation_fr_2026.xml"):
    chemin = os.path.join(dossier, "pack.zip")
    with zipfile.ZipFile(chemin, "w") as zf:
        zf.writestr("Pack/" + nom_lin, lin or _lin())
        zf.writestr("Pack/ORPHAnomenclature_fr_2026.xml", nom or _nom())
    return chemin


class Construit(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def test_entites_linearisees_seules_triees(self):
        lignes, r = b.construit(_pack(self.tmp.name))
        self.assertEqual([c[0] for c in lignes], ["10", "20"])
        self.assertEqual(r["ecartees"], 1)
        self.assertTrue(all(c[1] == "Maladie inventee rare" for c in lignes))

    def test_sigles_ecartes_sauf_liste_blanche(self):
        lignes, r = b.construit(_pack(self.tmp.name))
        d = {c[0]: c[3:] for c in lignes}
        self.assertEqual(d["10"], ["Maladie de Pifou", "SLA"])
        self.assertNotIn("SZ", d["20"])
        self.assertEqual(r["mentions_courtes_ecartees"], 2)

    def test_doublon_en_minuscules_supprime(self):
        lignes, _ = b.construit(_pack(self.tmp.name))
        d = {c[0]: c[3:] for c in lignes}
        self.assertEqual(d["20"], ["Syndrome de Zorglub", "Zorglubose"])

    def test_licence_inattendue_refusee(self):
        with self.assertRaises(SystemExit):
            b.construit(_pack(self.tmp.name, nom=_nom("CC-BY-NC-4.0")))

    def test_fichier_manquant_refuse(self):
        with self.assertRaises(SystemExit):
            b.construit(_pack(self.tmp.name, nom_lin="autre.xml"))

    def test_sortie_deterministe(self):
        lignes, r = b.construit(_pack(self.tmp.name))
        s1, s2 = (os.path.join(self.tmp.name, n) for n in ("a.gz", "b.gz"))
        b.ecrit(lignes, r, s1)
        b.ecrit(lignes, r, s2)
        with open(s1, "rb") as f1, open(s2, "rb") as f2:
            self.assertEqual(f1.read(), f2.read())
        texte = gzip.open(s1, "rt", encoding="utf-8").read()
        self.assertTrue(texte.startswith("# Orphanet"))
        self.assertIn("CC BY 4.0", texte.splitlines()[0])


if __name__ == "__main__":
    unittest.main()
