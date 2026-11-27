#!/usr/bin/env python3
"""Résume la sortie de `bench/mesure_temoins_homonymes.sh` par groupe de témoins (P2-320).

Entrée (stdin) : lignes « corpus | documents | avertis | part » de
`mesure_temoins_homonymes.sh`. Sortie : une ligne par groupe, lisible par
`etat.sh` (`montre`), `verifie_etat.py` et `controle_etat.py`.

Chemin mesuré : `Ecluse.redact` (le script appelé lance
`run_gardes_avertissements.dart`), pas le moteur seul. Le script ne compte que
des avertissements : aucune valeur d'un texte n'est lue ni écrite ici.

Pourquoi des groupes : P2-310, P2-315 et P2-318 ont chacune mesuré à la main le
bruit de l'avertissement « mot pris pour un nom commun » sur environ 74 corpus.
Sans surveillance, une régression (une règle de non-signalement qui saute)
passerait inaperçue. Le seuil de P2-310 est repris tel quel : plus de 5 % d'un
corpus témoin propre est un `ÉCHEC`, jamais un simple chiffre.

Groupes (d'après le nom du fichier) :
- `tournures_personne` : corpus fait de ces tournures, ce n'est pas un témoin
  de bruit ; compté à part, sans seuil ;
- `tournures_sans_nom` : tournures de phrase sans nom de personne, le pire
  témoin de la casse ordinaire ; seuil de 5 % ;
- minuscules : noms contenant `_minuscules`, `_mixte`, `_phrase` ou `transcrit`
  (texte sans majuscule, casse mixte, phrase, transcriptions) ; seuil de 5 % ;
- casse ordinaire : tous les autres ; seuil de 5 %.

Le seuil s'applique au pire corpus de chaque groupe (pas à la moyenne du groupe).
"""

import re
import sys

SEUIL = 5.0  # pour cent, seuil d'arrêt de P2-310
TOURNURES_PERSONNE = "tournures_personne"
TOURNURES_SANS_NOM = "tournures_sans_nom"
MARQUES_MINUSCULES = ("_minuscules", "_mixte", "_phrase", "transcrit")
LIGNE = re.compile(r"^(\S.*?) \| (\d+) \| (\d+) \| [\d.,]+ %$")


def nom(chemin):
    return chemin.rsplit("/", 1)[-1].removesuffix(".jsonl")


def groupe(chemin):
    n = nom(chemin)
    if TOURNURES_PERSONNE in n:
        return "personne"
    if TOURNURES_SANS_NOM in n:
        return "tournures"
    if any(m in n for m in MARQUES_MINUSCULES):
        return "minuscules"
    return "ordinaire"


def lit(lignes):
    """([(corpus, documents, avertis)], [lignes d'échec reprises])."""
    corpus, echecs, vus = [], [], set()
    for l in lignes:
        l = l.rstrip("\n")
        if l.startswith("ÉCHEC"):
            echecs.append(l)
            continue
        m = LIGNE.match(l)
        if m:
            c = (m.group(1), int(m.group(2)), int(m.group(3)))
            # Les corpus de tournures existent sous bench/flou/ (écrits par
            # `etat.sh`) et dans le dossier de travail du script : un même
            # corpus (nom, documents, avertis identiques) n'est compté qu'une fois.
            cle = (nom(c[0]).removeprefix("corpus_"), c[1], c[2])
            if cle not in vus:
                vus.add(cle)
                corpus.append(c)
    return corpus, echecs


def part(avertis, documents):
    return 100.0 * avertis / documents if documents else 0.0


def resume(lignes):
    """Les lignes à imprimer (les ÉCHEC comprises)."""
    corpus, echecs = lit(lignes)
    sortie = list(echecs)
    par = {"ordinaire": [], "minuscules": [], "tournures": [], "personne": []}
    for c in corpus:
        par[groupe(c[0])].append(c)
    titres = {
        "ordinaire": "casse ordinaire",
        "minuscules": "minuscules, mixte, phrase et transcrit",
    }
    for cle in ("ordinaire", "minuscules"):
        cs = par[cle]
        if not cs:
            sortie.append(f"ÉCHEC : aucun corpus mesuré pour le groupe {titres[cle]}")
            continue
        docs = sum(c[1] for c in cs)
        av = sum(c[2] for c in cs)
        pire = max(cs, key=lambda c: (part(c[2], c[1]), -len(c[0])))
        # Sans aucun avertissement, nommer « le pire » n'apprend rien.
        qui = f" ({nom(pire[0])})" if pire[2] else ""
        sortie.append(
            f"avertissements homonymes, {titres[cle]} : {len(cs)} corpus, "
            f"{docs} documents, {av} avertis, pire {part(pire[2], pire[1]):.2f} %"
            f"{qui}")
        if part(pire[2], pire[1]) > SEUIL:
            sortie.append(
                f"ÉCHEC : avertissements homonymes, {titres[cle]} : "
                f"{nom(pire[0])} dépasse {SEUIL:.0f} % d'un témoin propre")
    for cle, etiquette in (("tournures", TOURNURES_SANS_NOM),
                           ("personne", TOURNURES_PERSONNE)):
        cs = par[cle]
        if not cs:
            sortie.append(f"ÉCHEC : corpus {etiquette} absent de la mesure")
            continue
        docs = sum(c[1] for c in cs)
        av = sum(c[2] for c in cs)
        if cle == "tournures":
            sortie.append(
                f"avertissements homonymes, tournures sans nom : {av} / {docs} "
                f"({part(av, docs):.2f} %)")
            if part(av, docs) > SEUIL:
                sortie.append(
                    f"ÉCHEC : avertissements homonymes, tournures sans nom "
                    f"dépasse {SEUIL:.0f} % d'un témoin propre")
        else:
            sortie.append(
                f"avertissements homonymes, tournures de personne (corpus fait "
                f"de ces tournures, sans seuil) : {av} / {docs} "
                f"({part(av, docs):.2f} %)")
    return sortie


if __name__ == "__main__":
    for l in resume(sys.stdin):
        print(l)
