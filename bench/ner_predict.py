#!/usr/bin/env python3
"""Mesure du NER candidat sur les corpus flous (P2-89, poste du mainteneur).

Protocole : `bench/ner_predictions.md`. Ce script en automatise les § 3 à 5 :

  predire  : fait tourner le modèle sur les trois corpus flous, applique la
             correspondance des labels (§ 3), fusionne les spans voisins et
             écrit `flou/pred_ner_<corpus>.jsonl` au format du § 2 ; note la
             latence au 95e centile (documents d'environ 1 000 mots), la
             taille sur disque et la mémoire dans `flou/ner_perf.json`.
  scorer   : construit l'union Écluse + NER et lance `score_flou.py` sur les
             trois lignes (Écluse seul, NER seul, Écluse+NER).

Pourquoi un script plutôt que le bloc bash du protocole : le poste du
mainteneur est sous Windows, où la boucle `for c in …` et les heredocs ne
passent pas. Tout ici tourne avec `python` seul.

Dépendances **du poste seulement** (pas dans `requirements.txt`, rien n'est
ajouté au dépôt) : `transformers`, `torch`, `sentencepiece`, et `psutil`
pour la mémoire (facultatif). Les fonctions de correspondance et de fusion
n'en dépendent pas : elles sont testées dans `test_ner_predict.py`.

Rien de ce que produit ce script ne se versionne : ni prédictions, ni modèle
(`bench/flou/` est ignoré par git).
"""

import argparse
import json
import os
import statistics
import subprocess
import sys
import time

CORPUS = ("realiste", "adversarial", "temoin")

# § 3 : labels du modèle → type du corpus. Un label absent de la table est
# gardé tel quel (il compte pour la fuite au caractère, § 2).
CORRESPONDANCE = {
    "NOM_PERSONNE": "nom",
    "PRENOM_PERSONNE": "nom",
    "NUMERO_VOIE": "adresse",
    "NOM_VOIE": "adresse",
    "CODE_POSTAL": "adresse",
    "VILLE": "adresse",
    "TELEPHONE": "telephone",
    "EMAIL": "email",
    "NOM_SOCIETE": "etablissement",
}

# Séparateurs tolérés entre deux spans du même type pour les fusionner.
# Nom : au plus un blanc (« Odile » + « Marchetti »). Adresse : blancs,
# virgule, saut de ligne (« 12 rue des Lilas, 25000 Besançon »).
_SEP_NOM = {" ", " ", " ", "\t"}
_SEP_ADRESSE = _SEP_NOM | {",", "\n", "\r"}


def type_corpus(label):
    """Type du corpus pour un label du modèle (préfixes B-/I- retirés)."""
    brut = label.split("-", 1)[1] if label[:2] in ("B-", "I-") else label
    if brut in CORRESPONDANCE:
        return CORRESPONDANCE[brut]
    if "NAISSANCE" in brut:
        return "date_naissance"
    return brut


def fusionner(spans, texte):
    """Fusionne les spans voisins de même type (`nom`, `adresse`).

    `spans` : liste de dicts {type, start, end}. Renvoie une nouvelle liste
    triée. Deux `nom` sont fusionnés s'ils ne sont séparés que par **un**
    blanc au plus ; deux `adresse` s'ils ne sont séparés que par des blancs,
    des virgules ou des sauts de ligne.
    """
    out = []
    for s in sorted(spans, key=lambda e: (e["start"], e["end"])):
        if out and out[-1]["type"] == s["type"] and s["type"] in ("nom", "adresse"):
            prec = out[-1]
            entre = texte[prec["end"]:s["start"]]
            if s["start"] <= prec["end"]:
                ok = True
            elif s["type"] == "nom":
                ok = len(entre) <= 1 and all(c in _SEP_NOM for c in entre)
            else:
                ok = all(c in _SEP_ADRESSE for c in entre)
            if ok:
                prec["end"] = max(prec["end"], s["end"])
                continue
        out.append(dict(s))
    return out


def vers_entites(sorties, texte):
    """Sorties du pipeline transformers → entités du corpus, fusionnées."""
    spans = [
        {"type": type_corpus(e["entity_group"]),
         "start": int(e["start"]), "end": int(e["end"])}
        for e in sorties
        if e.get("start") is not None and e.get("end") is not None
    ]
    # Le tokenizer de CamemBERT rattache souvent le blanc qui précède au mot :
    # on le retire du span, il n'identifie personne.
    for s in spans:
        while s["start"] < s["end"] and texte[s["start"]].isspace():
            s["start"] += 1
    return fusionner([s for s in spans if s["end"] > s["start"]], texte)


def lire_jsonl(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]


def taille_dossier(chemin):
    total = 0
    for racine, _, fichiers in os.walk(chemin):
        for f in fichiers:
            total += os.path.getsize(os.path.join(racine, f))
    return total


def memoire_mo():
    try:
        import psutil  # facultatif
    except ImportError:
        return None
    return round(psutil.Process().memory_info().rss / 2**20, 1)


def predire(args):
    import torch
    from transformers import (AutoModelForTokenClassification, AutoTokenizer,
                              pipeline)

    tok = AutoTokenizer.from_pretrained(args.modele)
    if not tok.is_fast:
        sys.exit("Refus : le tokenizer n'est pas « fast », les offsets en "
                 "caractères et le stride ne seraient pas fiables.")
    modele = AutoModelForTokenClassification.from_pretrained(args.modele)
    labels = sorted(set(modele.config.id2label.values()))
    print("Labels du modèle (à relire, § 3) :", ", ".join(labels))
    inconnus = sorted({type_corpus(l) for l in labels} -
                      {"nom", "adresse", "telephone", "email", "etablissement",
                       "date_naissance", "O"})
    if inconnus:
        print("Gardés tels quels (fuite au caractère seulement) :",
              ", ".join(inconnus))
    if args.int8:
        # Quantification dynamique des couches linéaires : la variante qu'on
        # livrerait (§ 4, piège 2). Mesurer aussi sans --int8 pour comparer.
        modele = torch.quantization.quantize_dynamic(
            modele, {torch.nn.Linear}, dtype=torch.qint8)
    modele.eval()
    ner = pipeline("token-classification", model=modele, tokenizer=tok,
                   aggregation_strategy="simple", stride=args.stride)

    suffixe = "_int8" if args.int8 else ""
    for c in CORPUS:
        src = os.path.join(args.flou, f"corpus_flou_{c}.jsonl")
        if not os.path.exists(src):
            sys.exit(f"Refus : {src} absent. Générer d'abord les corpus "
                     "(§ 1 de ner_predictions.md).")
        docs = lire_jsonl(src)
        dst = os.path.join(args.flou, f"pred_ner{suffixe}_{c}.jsonl")
        with open(dst, "w", encoding="utf-8") as f:
            for d in docs:
                ents = vers_entites(ner(d["text"]), d["text"])
                f.write(json.dumps({"id": d["id"], "entities": ents},
                                   ensure_ascii=False) + "\n")
        print(f"{c} : {len(docs)} documents → {dst}")

    # Latence (condition E de P2-01) : documents d'environ 1 000 mots,
    # assemblés à partir du corpus réaliste, seed fixe pour l'ordre.
    textes = [d["text"] for d in lire_jsonl(
        os.path.join(args.flou, "corpus_flou_realiste.jsonl"))]
    longs, courant = [], []
    for t in textes:
        courant.append(t)
        if sum(len(x.split()) for x in courant) >= 1000:
            longs.append("\n\n".join(courant))
            courant = []
        if len(longs) >= args.n_latence:
            break
    ner(longs[0])  # échauffement, non compté
    durees = []
    for t in longs:
        t0 = time.perf_counter()
        ner(t)
        durees.append((time.perf_counter() - t0) * 1000)
    durees.sort()
    p95 = durees[max(0, int(round(0.95 * len(durees))) - 1)]
    perf = {
        "modele": args.modele,
        "int8": args.int8,
        "stride": args.stride,
        "documents_latence": len(durees),
        "mots_moyens": round(statistics.mean(len(t.split()) for t in longs)),
        "latence_ms_mediane": round(statistics.median(durees), 1),
        "latence_ms_p95": round(p95, 1),
        "taille_disque_mo": (round(taille_dossier(args.modele) / 2**20, 1)
                             if os.path.isdir(args.modele) else None),
        "memoire_rss_mo": memoire_mo(),
        "torch": torch.__version__,
    }
    dst = os.path.join(args.flou, f"ner_perf{suffixe}.json")
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(perf, f, indent=2, ensure_ascii=False)
    print(json.dumps(perf, indent=2, ensure_ascii=False))


def union(a, b, dst):
    pa = {d["id"]: d["entities"] for d in lire_jsonl(a)}
    pb = {d["id"]: d["entities"] for d in lire_jsonl(b)}
    with open(dst, "w", encoding="utf-8") as f:
        for i in sorted(pa.keys() | pb.keys()):
            f.write(json.dumps({"id": i, "entities": pa.get(i, []) + pb.get(i, [])},
                               ensure_ascii=False) + "\n")


def scorer(args):
    ici = os.path.dirname(os.path.abspath(__file__))
    racine = os.path.dirname(ici)
    suffixe = "_int8" if args.int8 else ""
    for c in CORPUS:
        corpus = os.path.join(args.flou, f"corpus_flou_{c}.jsonl")
        pred_e = os.path.join(args.flou, f"pred_{c}.jsonl")
        pred_n = os.path.join(args.flou, f"pred_ner{suffixe}_{c}.jsonl")
        pred_u = os.path.join(args.flou, f"pred_union{suffixe}_{c}.jsonl")
        if not args.sans_dart:
            subprocess.run(
                ["dart", "run", "bin/run_redact_bench.dart",
                 os.path.abspath(corpus), os.path.abspath(pred_e)],
                cwd=os.path.join(racine, "packages", "ecluse_redact"),
                check=True, stdin=subprocess.DEVNULL,
                shell=(os.name == "nt"))
        union(pred_e, pred_n, pred_u)
        print(f"\n===== {c} =====", flush=True)
        subprocess.run(
            [sys.executable, os.path.join(ici, "score_flou.py"),
             "--corpus", corpus,
             "--pred", f"Ecluse={pred_e}",
             "--pred", f"NER={pred_n}",
             "--pred", f"Ecluse+NER={pred_u}"],
            check=True)


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--flou", default=os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "flou"))
    p.add_argument("--int8", action="store_true",
                   help="quantification dynamique int8 (version livrée)")
    sub = p.add_subparsers(dest="cmd", required=True)
    pp = sub.add_parser("predire")
    pp.add_argument("modele", help="dossier local du modèle (ou identifiant Hugging Face)")
    pp.add_argument("--stride", type=int, default=64)
    pp.add_argument("--n-latence", type=int, default=30)
    ps = sub.add_parser("scorer")
    ps.add_argument("--sans-dart", action="store_true",
                    help="réutiliser flou/pred_<corpus>.jsonl déjà produits")
    args = p.parse_args()
    predire(args) if args.cmd == "predire" else scorer(args)


if __name__ == "__main__":
    main()
