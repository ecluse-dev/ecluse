#!/usr/bin/env python3
"""Exécute Microsoft Presidio sur le corpus et écrit ses prédictions.

Sortie JSONL : {"id": 0, "entities": [{"type": "iban", "start": 21, "end": 48}]}

Seules les entités comparables sont conservées (mapping ci-dessous).
Le seuil de score par défaut (0.35) correspond à l'usage conventionnel
de Presidio ; il est ajustable via --threshold.

`--recognizers simple|validated` ajoute deux reconnaisseurs NIR et RPPS écrits
à la main (sans nouvelle dépendance) : voir `french_recognizers`.

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
MAPPING = {"IBAN_CODE": "iban", "FR_NIR": "nir", "FR_RPPS": "rpps"}

# Séparateurs tolérés entre groupes de chiffres : espaces (dont insécable,
# tabulation, espaces multiples) et points. Volontairement généreux : on
# mesure le meilleur reconnaisseur raisonnable qu'un utilisateur de Presidio
# écrirait à la main, pas un reconnaisseur affaibli.
_SEP = r"[\s.]*"
_NIR_PATTERN = (
    rf"(?<!\d)[12]{_SEP}\d{{2}}{_SEP}\d{{2}}{_SEP}(?:\d{{2}}|2[AB]){_SEP}"
    rf"\d{{3}}{_SEP}\d{{3}}{_SEP}\d{{2}}(?!\d)"
)
_RPPS_PATTERN = r"(?<!\d)\d{5}[\s.]?\d{5}[\s.]?\d(?!\d)"


def _luhn_ok(digits: str) -> bool:
    total, double = 0, False
    for ch in reversed(digits):
        v = int(ch)
        if double:
            v *= 2
            if v > 9:
                v -= 9
        total += v
        double = not double
    return total % 10 == 0


def _nir_key_ok(raw: str) -> bool:
    compact = "".join(ch for ch in raw if ch.isalnum()).upper()
    if len(compact) != 15:
        return False
    body = compact[:13].replace("2A", "19", 1).replace("2B", "18", 1)
    if not body.isdigit() or not compact[13:].isdigit():
        return False
    return 97 - (int(body) % 97) == int(compact[13:])


def french_recognizers(validated: bool):
    """Deux reconnaisseurs écrits à la main, sans dépendance supplémentaire.

    `validated=False` : regex seule (ce que fait la plupart des intégrateurs).
    `validated=True` : la même regex + vérification de la clé (mod 97 pour le
    NIR, Luhn pour le RPPS) via `validate_result`, ce qui est la meilleure
    pratique documentée de Presidio. Les clés fausses sont alors écartées.
    """
    from presidio_analyzer import Pattern, PatternRecognizer

    class _Nir(PatternRecognizer):
        def validate_result(self, pattern_text):
            return _nir_key_ok(pattern_text) if validated else None

    class _Rpps(PatternRecognizer):
        def validate_result(self, pattern_text):
            digits = "".join(ch for ch in pattern_text if ch.isdigit())
            return _luhn_ok(digits) if validated else None

    return [
        _Nir(
            supported_entity="FR_NIR",
            patterns=[Pattern("nir", _NIR_PATTERN, 0.6)],
            supported_language="en",
        ),
        _Rpps(
            supported_entity="FR_RPPS",
            patterns=[Pattern("rpps", _RPPS_PATTERN, 0.4)],
            supported_language="en",
        ),
    ]


def build_engine(blank: bool, recognizers: str = "none"):
    engine = _base_engine(blank)
    if recognizers != "none":
        for rec in french_recognizers(validated=(recognizers == "validated")):
            engine.registry.add_recognizer(rec)
    return engine


def _base_engine(blank: bool):
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
    parser.add_argument(
        "--recognizers", choices=["none", "simple", "validated"], default="none",
        help="none = Presidio tel que livré ; simple = + NIR/RPPS par regex ; "
             "validated = + NIR/RPPS par regex et clé vérifiée (P1-35)")
    args = parser.parse_args()

    engine = build_engine(args.blank, args.recognizers)

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
