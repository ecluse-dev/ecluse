#!/usr/bin/env python3
"""P2-311 (mesure) : coût d'un masquage des SIRET sans le mot « siret » et des TVA
sans libellé, sur le corpus de `generate_corpus_references_14.py` (aucune
donnée personnelle : tout masquage y est en trop).

Entrée : paires `corpus.jsonl:pred.jsonl`, la prédiction venant de
`packages/ecluse_redact/bin/run_gardes_avertissements.dart` (`Ecluse.redact`,
chemin du produit : entités et avertissements). Le masquage est **simulé hors du
code produit** : un document serait masqué à tort si sa référence est lue par le
détecteur (quatorze chiffres collés ou groupés 3-3-3-5, de clé de Luhn juste ;
« FR » + clé + neuf chiffres pour la TVA) et que le mot « siret » ou le libellé
de TVA manque. Ne lit que des comptes : aucun texte n'est imprimé.

Colonnes : documents ; références à quatorze chiffres de Luhn juste ; masqués à
tort si on masquait (simulation) ; signalés aujourd'hui (avertissement
« SIRET … » ou « TVA … ») ; masqués aujourd'hui (une entité quelconque).
"""
import json
import re
import sys
from collections import Counter, defaultdict

# La compaction retire les blancs entre chiffres : toute écriture en groupes est lue.
LIT_14 = {"suivi_colis", "commande", "lot", "facture", "horodatage", "groupe_3335", "groupe_4442"}
TVA = {"tva_cle_fausse", "tva_cle_lettre"}
SIRET_W = re.compile(r"SIRET.*sans le mot")
TVA_W = re.compile(r"TVA.*sans libellé")


def main(paires):
    t = defaultdict(Counter)
    types = defaultdict(Counter)
    for p in paires:
        c, pr = p.split(":")
        corpus = [json.loads(l) for l in open(c, encoding="utf-8")]
        pred = {d["id"]: d for d in map(json.loads, open(pr, encoding="utf-8"))}
        for d in corpus:
            r = pred[d["id"]]
            f = d["forme"]
            k = t[f]
            k["docs"] += 1
            ref = d.get("ref", {})
            if ref.get("luhn"):
                k["luhn"] += 1
            if (f in LIT_14 and ref.get("luhn")) or f in TVA:
                k["masquerait"] += 1
            sig_siret = any(SIRET_W.search(w) for w in r["warnings"])
            sig_tva = any(TVA_W.search(w) for w in r["warnings"])
            if sig_siret:
                k["signale_siret"] += 1
            if sig_tva:
                k["signale_tva"] += 1
            if r["entities"]:
                k["masque_aujourdhui"] += 1
                for e in {e["type"] for e in r["entities"]}:
                    types[f][e] += 1
    print("forme | documents | réf. de Luhn juste | masqués à tort si on masquait | "
          "signalés SIRET | signalés TVA | masqués aujourd'hui")
    tot = Counter()
    ecarts = 0
    for f, k in t.items():
        print(f"{f} | {k['docs']} | {k['luhn']} | {k['masquerait']} | {k['signale_siret']} | "
              f"{k['signale_tva']} | {k['masque_aujourdhui']}")
        tot.update(k)
        # P2-313 : un horodatage valide n'est plus signalé (voulu) ; la colonne
        # « masqués à tort si on masquait » reste le coût d'un masquage.
        attendu = 0 if f == "horodatage" else k["masquerait"]
        if attendu != k["signale_siret"] + k["signale_tva"]:
            ecarts += 1
    print(f"TOTAL | {tot['docs']} | {tot['luhn']} | {tot['masquerait']} | {tot['signale_siret']} | "
          f"{tot['signale_tva']} | {tot['masque_aujourdhui']}")
    print("types d'entités masquées aujourd'hui (documents) :")
    for f, c in types.items():
        print(f"  {f} : " + ", ".join(f"{e} {n}" for e, n in sorted(c.items())))
    refs14 = sum(k["docs"] for f, k in t.items() if f in LIT_14)
    luhn14 = sum(k["luhn"] for f, k in t.items() if f in LIT_14)
    if refs14:
        print(f"part des références de quatorze chiffres de Luhn juste : {luhn14} / {refs14} "
              f"({100 * luhn14 / refs14:.1f} %)")
    print(f"formes où la simulation et les signalements diffèrent : {ecarts}")


if __name__ == "__main__":
    main(sys.argv[1:])
