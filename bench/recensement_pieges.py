#!/usr/bin/env python3
"""Recensement des pièges du générateur principal (P2-255, mesure).

Pour chaque forme de piège de `generate_corpus.py` (profils v3 et extended,
graine 42, 1 000 documents chacun), dit ce que `Ecluse.redact` (le chemin du
produit : ce que reçoit le LLM) en fait : masquée en entier, en partie, ou en
clair, avec les types prédits. Le moteur seul (`ecluse_core`) n'est pas
mesuré ici.

Rien n'est corrigé et aucune annotation n'est changée : le script lit le
corpus tel que le générateur l'écrit et n'imprime que des comptes, jamais une
valeur tirée d'un texte (les exemples sont des gabarits, pas des valeurs).

Usage, depuis la racine du dépôt (Dart et melos installés) :
    python3 bench/recensement_pieges.py

Les fichiers intermédiaires vont dans un dossier temporaire.
"""

import collections
import json
import os
import re
import subprocess
import sys
import tempfile

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(ICI)

# (famille de piège, gabarit reconnu, groupe(s) du piège)
FORMES = [
    ("nir_cle_fausse", re.compile(r"saisie erronée hier : (?P<p>.+?) a été rejeté par le contrôle\.")),
    ("iban_cle_fausse", re.compile(r"L'IBAN (?P<p>.+?) a été refusé par la banque \(clé invalide\)\.")),
    ("rpps_luhn_casse", re.compile(r"Le numéro (?P<p>\d+) ne correspond à aucun praticien connu\.")),
    ("telephone_fictif", re.compile(r"Contactez le secrétariat au (?P<p>.+?) pour toute question\.")),
    ("siret", re.compile(r"Le SIRET de l'établissement est (?P<p>\d+)\.")),
    ("siren_avec_mot", re.compile(r"Le SIREN de la société est (?P<p>.+?)\.$")),
    ("siren_sans_mot_rcs", re.compile(r"Société immatriculée au RCS de Metz sous le numéro (?P<p>.+?)\.$")),
    ("tva_intracom", re.compile(r"N° de TVA intracommunautaire : (?P<p>.+?)\.$")),
    ("siren_kbis", re.compile(r"Extrait Kbis : immatriculation (?P<p>.+?), gérant ")),
    ("adeli_cle_fausse", re.compile(r"Numéro ADELI saisi par erreur : (?P<p>.+?)\.$")),
    ("adeli_sans_mot", re.compile(r"Le kinésithérapeute est enregistré sous le numéro (?P<p>\d+) depuis 2015\.")),
    ("siren_voisin_finess", re.compile(r"société SIREN (?P<p>\d[\d ]*\d)\.$")),
    ("siren_avant_finess", re.compile(r"La société (?P<p>\d[\d ]*\d) exploite la structure FINESS ")),
]

# « trap_misc » : quatre formes, reconnues par leur contenu.
MISC = [
    ("misc_numero_dossier", re.compile(r"dossier n° \d{8}")),
    ("misc_date", re.compile(r"le \d{2}/\d{2}/\d{4}")),
    ("misc_code_postal_ville", re.compile(r"\d{5} (?:Paris|Lyon|Metz|Thionville|Nancy)")),
    ("misc_reference", re.compile(r"réf\. \d{10}")),
]
MISC_GABARITS = [
    re.compile(r"Réunion de service le mardi, (?P<p>.+), salle 203\."),
    re.compile(r"Voir (?P<p>.+?) et (?P<q>.+?) pour le détail\."),
]


def pieges(doc):
    """Rend [(famille, début, fin)] pour les pièges reconnus du document."""
    t = doc["text"]
    out = []
    for nom, rx in FORMES:
        m = rx.search(t)
        if m:
            out.append((nom, m.start("p"), m.end("p")))
    for rx in MISC_GABARITS:
        m = rx.search(t)
        if not m:
            continue
        for g in ("p", "q"):
            if g in rx.groupindex:
                for nom, rm in MISC:
                    if rm.fullmatch(m.group(g)):
                        out.append((nom, m.start(g), m.end(g)))
    return out


# Formes dont le piège s'écrit avec un préfixe qui n'est pas le numéro (libellé,
# « FR » de la clé TVA, « réf. ») : seuls les chiffres comptent, pour ne pas
# déclarer « en partie » un numéro entièrement masqué dont le libellé reste.
CHIFFRES_SEULS = {"misc_numero_dossier", "misc_reference", "misc_date",
                  "tva_intracom", "iban_cle_fausse", "adeli_cle_fausse"}


def couverture(t, debut, fin, preds, chiffres=False):
    """(caractères du piège, dont couverts, types prédits). Blancs exclus ;
    avec `chiffres`, seuls les chiffres comptent."""
    vus, couverts, types = 0, 0, set()
    for i in range(debut, fin):
        if t[i].isspace() or (chiffres and not t[i].isdigit()):
            continue
        vus += 1
        for p in preds:
            if p["start"] <= i < p["end"]:
                couverts += 1
                types.add(p["type"])
                break
    return vus, couverts, types


def lance(corpus, pred):
    commande = ["dart", "run", "bin/run_redact_bench.dart", corpus, pred]
    r = subprocess.run(commande, cwd=os.path.join(RACINE, "packages", "ecluse_redact"),
                       stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                       stderr=subprocess.PIPE, text=True)
    if r.returncode != 0 or not os.path.exists(pred):
        sys.exit("ÉCHEC : run_redact_bench (code %d)" % r.returncode)


def mesure(profil, dossier):
    corpus = os.path.join(dossier, f"corpus_{profil}.jsonl")
    pred = os.path.join(dossier, f"pred_{profil}.jsonl")
    subprocess.run([sys.executable, os.path.join(ICI, "generate_corpus.py"),
                    "--n", "1000", "--seed", "42", "--profile", profil, "--out", corpus],
                   check=True, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
    lance(corpus, pred)
    docs = [json.loads(l) for l in open(corpus, encoding="utf-8")]
    preds = {}
    for l in open(pred, encoding="utf-8"):
        d = json.loads(l)
        preds[d["id"]] = d["entities"]
    # Compte, par famille : annotée ou non (au document), entier / partie / clair.
    res = collections.OrderedDict()
    for d in docs:
        annotes = d["entities"]
        for nom, s, e in pieges(d):
            vus, cov, types = couverture(d["text"], s, e, preds[d["id"]],
                                         nom in CHIFFRES_SEULS)
            ann = any(a["start"] <= s and a["end"] >= e for a in annotes)
            r = res.setdefault(nom, collections.Counter())
            r["n"] += 1
            r["annotes"] += 1 if ann else 0
            r["entier" if cov == vus else ("clair" if cov == 0 else "partie")] += 1
            for ty in sorted(types):
                r["type=" + ty] += 1
    return res


def main():
    with tempfile.TemporaryDirectory() as dossier:
        for profil in ("v3", "extended"):
            res = mesure(profil, dossier)
            print(f"## profil {profil} : Ecluse.redact (chemin du produit), graine 42, 1000 documents")
            for nom, r in sorted(res.items()):
                types = ", ".join(f"{k[5:]} {v}" for k, v in sorted(r.items()) if k.startswith("type="))
                print(f"  {nom} : {r['n']} pièges, {r['annotes']} annotés ; masqués en entier {r['entier']}, "
                      f"en partie {r['partie']}, en clair {r['clair']} ; types prédits : {types or 'aucun'}")


if __name__ == "__main__":
    main()
