#!/usr/bin/env python3
"""Exécute Microsoft Presidio sur le corpus et écrit ses prédictions.

Sortie JSONL : {"id": 0, "entities": [{"type": "iban", "start": 21, "end": 48}]}

Seules les entités comparables sont conservées (mapping ci-dessous).
Le seuil de score par défaut (0.35) correspond à l'usage conventionnel
de Presidio ; il est ajustable via --threshold.

Par défaut, utilise le modèle spaCy en_core_web_lg (configuration
out-of-the-box de Presidio). Si --blank est passé, utilise un pipeline
spaCy vierge : suffisant pour les recognizers à motifs (IBAN, etc.),
utile dans les environnements sans accès aux modèles.
"""

import argparse
import json
import warnings

warnings.filterwarnings("ignore")

# Entités Presidio -> types du corpus. Tout le reste est ignoré
# (on ne pénalise pas Presidio pour ses détections hors périmètre).
MAPPING = {"IBAN_CODE": "iban"}


def build_engine(blank: bool):
    from presidio_analyzer import AnalyzerEngine

    if not blank:
        return AnalyzerEngine()

    import os
    import tempfile

    import spacy
    from presidio_analyzer.nlp_engine import NlpEngineProvider

    path = os.path.join(tempfile.gettempdir(), "presidio_blank_en")
    spacy.blank("en").to_disk(path)
    conf = {
        "nlp_engine_name": "spacy",
        "models": [{"lang_code": "en", "model_name": path}],
    }
    nlp_engine = NlpEngineProvider(nlp_configuration=conf).create_engine()
    return AnalyzerEngine(nlp_engine=nlp_engine)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", default="corpus.jsonl")
    parser.add_argument("--out", default="predictions_presidio.jsonl")
    parser.add_argument("--threshold", type=float, default=0.35)
    parser.add_argument("--blank", action="store_true",
                        help="pipeline spaCy vierge (recognizers à motifs uniquement)")
    args = parser.parse_args()

    engine = build_engine(args.blank)

    n_docs = 0
    n_ents = 0
    with open(args.corpus, encoding="utf-8") as fin, \
            open(args.out, "w", encoding="utf-8") as fout:
        for line in fin:
            doc = json.loads(line)
            results = engine.analyze(text=doc["text"], language="en")
            entities = []
            for r in results:
                mapped = MAPPING.get(r.entity_type)
                if mapped is None or r.score < args.threshold:
                    continue
                entities.append({"type": mapped, "start": r.start, "end": r.end})
            fout.write(json.dumps({"id": doc["id"], "entities": entities},
                                  ensure_ascii=False) + "\n")
            n_docs += 1
            n_ents += len(entities)

    print(f"Presidio : {n_docs} documents analysés, {n_ents} entités retenues "
          f"(seuil {args.threshold}) -> {args.out}")


if __name__ == "__main__":
    main()
