# ecluse_llm

Interfaces Dart pures pour l'usage d'un **petit LLM local** dans la couche
d'anonymisation d'Ecluse.

## Positionnement

Ce package **n'embarque pas de modèle** et **ne parle à aucun LLM tiers**.
Il définit les contrats consommés par une implémentation concrète — typiquement
`ecluse_llm_onnx` pour du CPU/GPU local via ONNX Runtime, ou un adaptateur
Ollama HTTP pour du prototypage.

Le LLM local dans Ecluse a **trois rôles autorisés** :

1. **Vérificateur post-redact** — relit le texte anonymisé, cherche des
   fuites résiduelles (quasi-identifiants sémantiques, coréférences,
   ambiguïtés), retourne des `LeakSpan` à ajouter.
2. **Moteur du jalon `reid`** — propose des généralisations contextuelles
   pour un tuple `(profession, lieu, âge)` réidentifiable.
3. **Désambiguïsateur** — tranche des cas où un détecteur structurel ou le
   NER hésitent (« Marie » prénom vs verbe, « Port » ville vs action).

## Ce que le LLM **ne fait pas**

- **Il ne réécrit jamais le texte utilisateur.** Pas de paraphrase, pas de
  résumé, pas de reformulation. Le LLM annote et suggère ; il ne substitue
  pas la vérité du prompt d'origine. C'est ce qui protège la traçabilité
  et les offsets.
- Il ne remplace ni les détecteurs structurels (`NIR`, `RPPS`, `FINESS`,
  `IBAN`) ni le NER. Il ajoute une couche par-dessus. Priorité assumée
  dans `resolveOverlaps` : `structuralValidated > ner > llm`.

## Contrats

```dart
abstract class LlmClient {
  Future<LlmResponse> complete(LlmPrompt prompt);
  void close();
}

abstract class RedactVerifier {
  Future<VerificationResult> verify({
    required String originalText,
    required String redactedText,
    required List<Span> existingSpans,
  });
}
```

Voir `lib/src/verifier.dart` pour l'implémentation par défaut
`LlmRedactVerifier`, qui délègue à un `LlmClient` fourni.

## Éval

Ce package s'appuie sur le corpus `bench/` d'Ecluse. Discipline « zéro
communication avant preuve » : mesure NER seul vs NER + LLM sur les
mêmes 20 plannings réels attendus pour le GO/STOP du NER.

## Statut

Scaffold. Aucune implémentation concrète — voir `ecluse_llm_onnx`.
