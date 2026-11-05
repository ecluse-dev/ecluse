# Mesurer le vérificateur LLM sur les corpus sémantiques (P2-107)

Ce document dit comment produire et scorer les prédictions d'un petit LLM
local pour le critère GO/STOP de `agent/specs/P2-104.md`, **sans** fusionner
la branche `feat/llm-scaffold` ni ajouter de dépendance au dépôt (règle 7 de
`CLAUDE.md`). Le modèle tourne sur le poste du mainteneur (machine de
référence, décision P2-87) ; seul le score revient dans le dépôt.

Candidat de départ : **SmolLM3-3B** (`agent/specs/P2-106.md`). La mesure
attend la décision sur le NER (P2-90, décision P2-104a).

## 1. Corpus

```bash
mkdir -p bench/semantique/pred
python3 bench/generate_corpus_semantique.py --n 300 --seed 42 --out-dir bench/semantique
```

Trois fichiers `corpus_semantique_{indices,temoin,injection}.jsonl`. Le
champ `text` est le texte **d'origine**.

## 2. Ce que reçoit le vérificateur

Le contrat de la branche (`RedactVerifier.verify`) prend trois entrées :

1. le texte d'origine (`text` du corpus) ;
2. le texte masqué : `Ecluse.redact(text)` sur `main`, dans sa
   configuration par défaut ;
3. les spans déjà détectés : les `entities` de ce même résultat.

Le texte masqué s'obtient sur le poste avec un petit script Dart jetable,
**non versionné**, qui lit le corpus et écrit une ligne par document :

```dart
// mesure_semantique.dart (jetable, à lancer depuis packages/ecluse_redact)
import 'dart:convert';
import 'dart:io';
import 'package:ecluse_redact/ecluse_redact.dart';

Future<void> main(List<String> args) async {
  final sortie = File(args[1]).openWrite();
  for (final ligne in File(args[0]).readAsLinesSync()) {
    final doc = jsonDecode(ligne) as Map<String, dynamic>;
    final r = await Ecluse.redact(doc['text'] as String);
    sortie.writeln(jsonEncode({
      'id': doc['id'],
      'masque': r.maskedText,
      'spans': [
        for (final e in r.entities)
          {'start': e.start, 'end': e.end, 'type': e.type.name},
      ],
    }));
  }
  await sortie.close();
}
```

## 3. Prompt et appel du modèle

Reprendre **tel quel** le prompt versionné `v1` de
`VerifierPromptBuilder` (branche `feat/llm-scaffold`,
`packages/ecluse_llm/lib/src/prompt_builder.dart`) : message système, blocs
`ORIGINAL`, `ANONYMISÉ` et `SPANS DÉJÀ DÉTECTÉS`, température 0, schéma
JSON. Si le prompt change pendant la mesure, changer sa version et le noter
dans le rapport.

Le modèle tourne localement, quantifié (la taille quantifiée entre dans la
condition F). Utiliser un moteur qui sait **contraindre la sortie au schéma
JSON** et fixer la graine. Les options exactes dépendent du moteur choisi et
ne sont pas vérifiées ici.

## 4. Des réponses aux prédictions

Une ligne par document dans `bench/semantique/pred/pred_semantique_<corpus>.jsonl` :

```json
{"id": 12, "statut": "verifie", "signalements": [{"start": 40, "end": 71}]}
```

Règles, qui découlent de la condition D :

- **`statut: "non_verifie"`** si la réponse n'est pas un JSON conforme au
  schéma, si l'appel échoue ou dépasse le délai, ou si le texte a été
  **tronqué** (le prompt `v1` coupe à 4 000 caractères ; les documents du
  corpus sont plus courts, mais la règle vaut pour la suite). Ne jamais
  écrire `"verifie"` avec une liste vide dans ces cas.
- **Offsets** : un signalement dont `start`/`end` sort du texte d'origine,
  ou avec `start >= end`, est **rejeté** et compté à part, jamais corrigé.
  C'est déjà ce que fait `parseLeakSpansJson`.
- Garder la réponse brute de chaque document dans un fichier à part, non
  versionné, pour le rapport.

**Piège de la branche à ne pas reproduire** : `LlmRedactVerifier` rend une
liste vide avec un simple avertissement quand l'analyse échoue, et
`VerificationResult.isClean` vaut alors `true`. Pour la mesure, un
avertissement « verification skipped » donne `"non_verifie"`. La correction
du code est la tâche P2-109.

## 5. Scorer

```bash
python3 bench/score_semantique.py --dir bench/semantique --pred-dir bench/semantique/pred
```

Le scoreur rend les conditions A, C, D et E. Mesurer en plus, pour le
rapport :

- **D, déterminisme** : relancer les trois corpus et comparer les fichiers
  de prédictions ; ils doivent être identiques ;
- **D, offsets** : le nombre de signalements rejetés pour offsets invalides ;
- **F** : taille du modèle quantifié sur disque, latence au 95e centile par
  document, mémoire maximale, sur la machine de référence.

Un petit LLM se trompe souvent sur les offsets en caractères. Si le taux de
rejet est élevé, le noter : c'est une information pour P2-108, pas une
raison de corriger les offsets à la main.

## 6. Ce qui revient dans le dépôt

Un rapport (tâche de mesure, sans correction) : les quatre lignes du
scoreur, le taux de rejet des offsets, le déterminisme, F, la version du
prompt, le modèle, sa quantification et le moteur. **Jamais** les
prédictions, les réponses brutes ni le modèle.
