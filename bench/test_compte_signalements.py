#!/usr/bin/env python3
"""Tests de `compte_signalements_a_tort.py` (P2-291) : `python3 -m unittest
discover -s bench`. Prédictions synthétiques, aucun texte."""
import json
import os
import tempfile
import unittest

import compte_signalements_a_tort as c


def ecrit(lignes):
    f = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False, encoding="utf-8")
    for l in lignes:
        f.write(json.dumps(l) + "\n")
    f.close()
    return f.name


class CompteTest(unittest.TestCase):
    def test_compte_signalees_et_masquees_separement(self):
        p = ecrit([
            {"id": 1, "entities": [], "signalements": 0},
            {"id": 2, "entities": [], "signalements": 2},
            {"id": 3, "entities": [{"type": "nir", "start": 0, "end": 5}], "signalements": 0},
            {"id": 4, "entities": [{"type": "nir", "start": 0, "end": 5}], "signalements": 1},
        ])
        try:
            self.assertEqual(c.compte(p), (4, 2, 2))
        finally:
            os.unlink(p)

    def test_un_fichier_vide_est_refuse(self):
        p = ecrit([])
        try:
            with self.assertRaises(SystemExit):
                c.compte(p)
        finally:
            os.unlink(p)


if __name__ == "__main__":
    unittest.main()
